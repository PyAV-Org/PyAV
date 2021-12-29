from cython.operator cimport dereference
from libc.stdint cimport int64_t
from libc.stdlib cimport free, malloc

import os
import time

cimport libav as lib

from av.container.core cimport timeout_info
from av.container.input cimport InputContainer
from av.container.output cimport OutputContainer
from av.container.pyio cimport pyio_read, pyio_seek, pyio_write
from av.enum cimport define_enum
from av.error cimport err_check, stash_exception
from av.format cimport build_container_format

from av.dictionary import Dictionary
from av.logging import Capture as LogCapture


ctypedef int64_t (*seek_func_t)(void *opaque, int64_t offset, int whence) nogil


cdef object _cinit_sentinel = object()


# We want to use the monotonic clock if it is available.
cdef object clock = getattr(time, 'monotonic', time.time)

cdef int interrupt_cb (void *p) nogil:

    cdef timeout_info info = dereference(<timeout_info*> p)
    if info.timeout < 0:  # timeout < 0 means no timeout
        return 0

    cdef double current_time
    with gil:

        current_time = clock()

        # Check if the clock has been changed.
        if current_time < info.start_time:
            # Raise this when we get back to Python.
            stash_exception((RuntimeError, RuntimeError("Clock has been changed to before timeout start"), None))
            return 1

    if current_time > info.start_time + info.timeout:
        return 1

    return 0


Flags = define_enum('Flags', __name__, (
    ('GENPTS', lib.AVFMT_FLAG_GENPTS,
        "Generate missing pts even if it requires parsing future frames."),
    ('IGNIDX', lib.AVFMT_FLAG_IGNIDX,
        "Ignore index."),
    ('NONBLOCK', lib.AVFMT_FLAG_NONBLOCK,
        "Do not block when reading packets from input."),
    ('IGNDTS', lib.AVFMT_FLAG_IGNDTS,
        "Ignore DTS on frames that contain both DTS & PTS."),
    ('NOFILLIN', lib.AVFMT_FLAG_NOFILLIN,
        "Do not infer any values from other values, just return what is stored in the container."),
    ('NOPARSE', lib.AVFMT_FLAG_NOPARSE,
        """Do not use AVParsers, you also must set AVFMT_FLAG_NOFILLIN as the fillin code works on frames and no parsing -> no frames.

        Also seeking to frames can not work if parsing to find frame boundaries has been disabled."""),
    ('NOBUFFER', lib.AVFMT_FLAG_NOBUFFER,
        "Do not buffer frames when possible."),
    ('CUSTOM_IO', lib.AVFMT_FLAG_CUSTOM_IO,
        "The caller has supplied a custom AVIOContext, don't avio_close() it."),
    ('DISCARD_CORRUPT', lib.AVFMT_FLAG_DISCARD_CORRUPT,
        "Discard frames marked corrupted."),
    ('FLUSH_PACKETS', lib.AVFMT_FLAG_FLUSH_PACKETS,
        "Flush the AVIOContext every packet."),
    ('BITEXACT', lib.AVFMT_FLAG_BITEXACT,
        """When muxing, try to avoid writing any random/volatile data to the output.

        This includes any random IDs, real-time timestamps/dates, muxer version, etc.
        This flag is mainly intended for testing."""),
    ('MP4A_LATM', lib.AVFMT_FLAG_MP4A_LATM,
        "Enable RTP MP4A-LATM payload"),
    ('SORT_DTS', lib.AVFMT_FLAG_SORT_DTS,
        "Try to interleave outputted packets by dts (using this flag can slow demuxing down)."),
    ('PRIV_OPT', lib.AVFMT_FLAG_PRIV_OPT,
        "Enable use of private options by delaying codec open (this could be made default once all code is converted)."),
    ('KEEP_SIDE_DATA', lib.AVFMT_FLAG_KEEP_SIDE_DATA,
        "Deprecated, does nothing."),
    ('FAST_SEEK', lib.AVFMT_FLAG_FAST_SEEK,
        "Enable fast, but inaccurate seeks for some formats."),
    ('SHORTEST', lib.AVFMT_FLAG_SHORTEST,
        "Stop muxing when the shortest stream stops."),
    ('AUTO_BSF', lib.AVFMT_FLAG_AUTO_BSF,
        "Add bitstream filters as requested by the muxer."),
), is_flags=True)


cdef class Container(object):

    def __cinit__(self, sentinel, file_, format_name, options,
                  container_options, stream_options,
                  metadata_encoding, metadata_errors,
                  buffer_size, open_timeout, read_timeout):

        if sentinel is not _cinit_sentinel:
            raise RuntimeError('cannot construct base Container')

        self.writeable = isinstance(self, OutputContainer)
        if not self.writeable and not isinstance(self, InputContainer):
            raise RuntimeError('Container cannot be directly extended.')

        if isinstance(file_, str):
            self.name = file_
        else:
            self.name = getattr(file_, 'name', '<none>')
            if not isinstance(self.name, str):
                raise TypeError("File's name attribute must be string-like.")
            self.file = file_

        self.options = dict(options or ())
        self.container_options = dict(container_options or ())
        self.stream_options = [dict(x) for x in stream_options or ()]

        self.metadata_encoding = metadata_encoding
        self.metadata_errors = metadata_errors

        self.open_timeout = open_timeout
        self.read_timeout = read_timeout

        if format_name is not None:
            self.format = ContainerFormat(format_name)

        self.input_was_opened = False
        cdef int res

        cdef bytes name_obj = os.fsencode(self.name)
        cdef char *name = name_obj
        cdef seek_func_t seek_func = NULL

        cdef lib.AVOutputFormat *ofmt
        if self.writeable:

            ofmt = self.format.optr if self.format else lib.av_guess_format(NULL, name, NULL)
            if ofmt == NULL:
                raise ValueError("Could not determine output format")

            with nogil:
                # This does not actually open the file.
                res = lib.avformat_alloc_output_context2(
                    &self.ptr,
                    ofmt,
                    NULL,
                    name,
                )
            self.err_check(res)

        else:
            # We need the context before we open the input AND setup Python IO.
            self.ptr = lib.avformat_alloc_context()

            # Setup interrupt callback
            if self.open_timeout is not None or self.read_timeout is not None:
                self.ptr.interrupt_callback.callback = interrupt_cb
                self.ptr.interrupt_callback.opaque = &self.interrupt_callback_info

        self.ptr.flags |= lib.AVFMT_FLAG_GENPTS

        # Setup Python IO.
        if self.file is not None:

            self.fread = getattr(self.file, 'read', None)
            self.fwrite = getattr(self.file, 'write', None)
            self.fseek = getattr(self.file, 'seek', None)
            self.ftell = getattr(self.file, 'tell', None)

            if self.writeable:
                if self.fwrite is None:
                    raise ValueError("File object has no write method.")
            else:
                if self.fread is None:
                    raise ValueError("File object has no read method.")

            if self.fseek is not None and self.ftell is not None:
                seek_func = pyio_seek

            self.pos = 0
            self.pos_is_valid = True

            # This is effectively the maximum size of reads.
            self.buffer = <unsigned char*>lib.av_malloc(buffer_size)

            self.iocontext = lib.avio_alloc_context(
                self.buffer, buffer_size,
                self.writeable,  # Writeable.
                <void*>self,  # User data.
                pyio_read,
                pyio_write,
                seek_func
            )

            if seek_func:
                self.iocontext.seekable = lib.AVIO_SEEKABLE_NORMAL
            self.iocontext.max_packet_size = buffer_size
            self.ptr.pb = self.iocontext

        cdef lib.AVInputFormat *ifmt
        cdef _Dictionary c_options
        if not self.writeable:

            ifmt = self.format.iptr if self.format else NULL

            c_options = Dictionary(self.options, self.container_options)

            self.set_timeout(self.open_timeout)
            self.start_timeout()
            with nogil:
                res = lib.avformat_open_input(
                    &self.ptr,
                    name,
                    ifmt,
                    &c_options.ptr
                )
            self.set_timeout(None)
            self.err_check(res)
            self.input_was_opened = True

        if format_name is None:
            self.format = build_container_format(self.ptr.iformat, self.ptr.oformat)

    def __dealloc__(self):
        with nogil:
            # FFmpeg will not release custom input, so it's up to us to free it.
            # Do not touch our original buffer as it may have been freed and replaced.
            if self.iocontext:
                lib.av_freep(&self.iocontext.buffer)
                lib.av_freep(&self.iocontext)

            # We likely errored badly if we got here, and so are still
            # responsible for our buffer.
            else:
                lib.av_freep(&self.buffer)

            # Finish releasing the whole structure.
            lib.avformat_free_context(self.ptr)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def __repr__(self):
        return '<av.%s %r>' % (self.__class__.__name__, self.file or self.name)

    cdef int err_check(self, int value) except -1:
        return err_check(value, filename=self.name)

    def dumps_format(self):
        with LogCapture() as logs:
            lib.av_dump_format(self.ptr, 0, "", isinstance(self, OutputContainer))
        return ''.join(log[2] for log in logs)

    cdef set_timeout(self, timeout):
        if timeout is None:
            self.interrupt_callback_info.timeout = -1.0
        else:
            self.interrupt_callback_info.timeout = timeout

    cdef start_timeout(self):
        self.interrupt_callback_info.start_time = clock()

    def _get_flags(self):
        return self.ptr.flags

    def _set_flags(self, value):
        self.ptr.flags = value

    flags = Flags.property(
        _get_flags,
        _set_flags,
        """Flags property of :class:`.Flags`"""
    )

    gen_pts = flags.flag_property('GENPTS')
    ign_idx = flags.flag_property('IGNIDX')
    non_block = flags.flag_property('NONBLOCK')
    ign_dts = flags.flag_property('IGNDTS')
    no_fill_in = flags.flag_property('NOFILLIN')
    no_parse = flags.flag_property('NOPARSE')
    no_buffer = flags.flag_property('NOBUFFER')
    custom_io = flags.flag_property('CUSTOM_IO')
    discard_corrupt = flags.flag_property('DISCARD_CORRUPT')
    flush_packets = flags.flag_property('FLUSH_PACKETS')
    bit_exact = flags.flag_property('BITEXACT')
    mp4a_latm = flags.flag_property('MP4A_LATM')
    sort_dts = flags.flag_property('SORT_DTS')
    priv_opt = flags.flag_property('PRIV_OPT')
    keep_side_data = flags.flag_property('KEEP_SIDE_DATA')
    fast_seek = flags.flag_property('FAST_SEEK')
    shortest = flags.flag_property('SHORTEST')
    auto_bsf = flags.flag_property('AUTO_BSF')


def open(file, mode=None, format=None, options=None,
         container_options=None, stream_options=None,
         metadata_encoding='utf-8', metadata_errors='strict',
         buffer_size=32768, timeout=None):
    """open(file, mode='r', **kwargs)

    Main entrypoint to opening files/streams.

    :param str file: The file to open, which can be either a string or a file-like object.
    :param str mode: ``"r"`` for reading and ``"w"`` for writing.
    :param str format: Specific format to use. Defaults to autodect.
    :param dict options: Options to pass to the container and all streams.
    :param dict container_options: Options to pass to the container.
    :param list stream_options: Options to pass to each stream.
    :param str metadata_encoding: Encoding to use when reading or writing file metadata.
        Defaults to ``"utf-8"``.
    :param str metadata_errors: Specifies how to handle encoding errors; behaves like
        ``str.encode`` parameter. Defaults to ``"strict"``.
    :param int buffer_size: Size of buffer for Python input/output operations in bytes.
        Honored only when ``file`` is a file-like object. Defaults to 32768 (32k).
    :param timeout: How many seconds to wait for data before giving up, as a float, or a
        :ref:`(open timeout, read timeout) <timeouts>` tuple.
    :type timeout: float or tuple

    For devices (via ``libavdevice``), pass the name of the device to ``format``,
    e.g.::

        >>> # Open webcam on OS X.
        >>> av.open(format='avfoundation', file='0') # doctest: +SKIP

    .. seealso:: :ref:`garbage_collection`

    More information on using input and output devices is available on the
    `FFmpeg website <https://www.ffmpeg.org/ffmpeg-devices.html>`_.
    """

    if mode is None:
        mode = getattr(file, 'mode', None)
    if mode is None:
        mode = 'r'

    if isinstance(timeout, tuple):
        open_timeout = timeout[0]
        read_timeout = timeout[1]
    else:
        open_timeout = timeout
        read_timeout = timeout

    if mode.startswith('r'):
        return InputContainer(
            _cinit_sentinel, file, format, options,
            container_options, stream_options,
            metadata_encoding, metadata_errors,
            buffer_size, open_timeout, read_timeout
        )
    if mode.startswith('w'):
        if stream_options:
            raise ValueError("Provide stream options via Container.add_stream(..., options={}).")
        return OutputContainer(
            _cinit_sentinel, file, format, options,
            container_options, stream_options,
            metadata_encoding, metadata_errors,
            buffer_size, open_timeout, read_timeout
        )
    raise ValueError("mode must be 'r' or 'w'; got %r" % mode)
