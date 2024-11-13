from cython.operator cimport dereference
from libc.stdint cimport int64_t

import os
import time
from enum import Flag
from pathlib import Path

cimport libav as lib

from av.container.core cimport timeout_info
from av.container.input cimport InputContainer
from av.container.output cimport OutputContainer
from av.container.pyio cimport pyio_close_custom_gil, pyio_close_gil
from av.error cimport err_check, stash_exception
from av.format cimport build_container_format
from av.utils cimport avdict_to_dict

from av.dictionary import Dictionary
from av.logging import Capture as LogCapture


cdef object _cinit_sentinel = object()


# We want to use the monotonic clock if it is available.
cdef object clock = getattr(time, "monotonic", time.time)

cdef int interrupt_cb (void *p) noexcept nogil:
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


cdef int pyav_io_open(lib.AVFormatContext *s,
                      lib.AVIOContext **pb,
                      const char *url,
                      int flags,
                      lib.AVDictionary **options) noexcept nogil:
    with gil:
        return pyav_io_open_gil(s, pb, url, flags, options)


cdef int pyav_io_open_gil(lib.AVFormatContext *s,
                          lib.AVIOContext **pb,
                          const char *url,
                          int flags,
                          lib.AVDictionary **options) noexcept:
    cdef Container container
    cdef object file
    cdef PyIOFile pyio_file
    try:
        container = <Container>dereference(s).opaque

        if options is not NULL:
            options_dict = avdict_to_dict(
                dereference(<lib.AVDictionary**>options),
                encoding=container.metadata_encoding,
                errors=container.metadata_errors
            )
        else:
            options_dict = {}

        file = container.io_open(
            <str>url if url is not NULL else "",
            flags,
            options_dict
        )

        pyio_file = PyIOFile(
            file,
            container.buffer_size,
            (flags & lib.AVIO_FLAG_WRITE) != 0
        )

        # Add it to the container to avoid it being deallocated
        container.open_files[<int64_t>pyio_file.iocontext.opaque] = pyio_file

        pb[0] = pyio_file.iocontext
        return 0

    except Exception as e:
        return stash_exception()


cdef int pyav_io_close(lib.AVFormatContext *s, lib.AVIOContext *pb) noexcept nogil:
    with gil:
        return pyav_io_close_gil(s, pb)

cdef int pyav_io_close_gil(lib.AVFormatContext *s, lib.AVIOContext *pb) noexcept:
    cdef Container container
    cdef int result = 0
    try:
        container = <Container>dereference(s).opaque

        if container.open_files is not None and <int64_t>pb.opaque in container.open_files:
            result = pyio_close_custom_gil(pb)

            # Remove it from the container so that it can be deallocated
            del container.open_files[<int64_t>pb.opaque]
        else:
            result = pyio_close_gil(pb)

    except Exception as e:
        stash_exception()
        result = lib.AVERROR_UNKNOWN  # Or another appropriate error code

    return result


class Flags(Flag):
    gen_pts: "Generate missing pts even if it requires parsing future frames." = lib.AVFMT_FLAG_GENPTS
    ign_idx: "Ignore index." = lib.AVFMT_FLAG_IGNIDX
    non_block: "Do not block when reading packets from input." = lib.AVFMT_FLAG_NONBLOCK
    ign_dts: "Ignore DTS on frames that contain both DTS & PTS." = lib.AVFMT_FLAG_IGNDTS
    no_fillin: "Do not infer any values from other values, just return what is stored in the container." = lib.AVFMT_FLAG_NOFILLIN
    no_parse: "Do not use AVParsers, you also must set AVFMT_FLAG_NOFILLIN as the fillin code works on frames and no parsing -> no frames. Also seeking to frames can not work if parsing to find frame boundaries has been disabled." = lib.AVFMT_FLAG_NOPARSE
    no_buffer: "Do not buffer frames when possible." = lib.AVFMT_FLAG_NOBUFFER
    custom_io: "The caller has supplied a custom AVIOContext, don't avio_close() it." = lib.AVFMT_FLAG_CUSTOM_IO
    discard_corrupt: "Discard frames marked corrupted." = lib.AVFMT_FLAG_DISCARD_CORRUPT
    flush_packets: "Flush the AVIOContext every packet." = lib.AVFMT_FLAG_FLUSH_PACKETS
    bitexact: "When muxing, try to avoid writing any random/volatile data to the output. This includes any random IDs, real-time timestamps/dates, muxer version, etc. This flag is mainly intended for testing." = lib.AVFMT_FLAG_BITEXACT
    sort_dts: "Try to interleave outputted packets by dts (using this flag can slow demuxing down)." = lib.AVFMT_FLAG_SORT_DTS
    fast_seek: "Enable fast, but inaccurate seeks for some formats." = lib.AVFMT_FLAG_FAST_SEEK
    shortest: "Stop muxing when the shortest stream stops." = lib.AVFMT_FLAG_SHORTEST
    auto_bsf: "Add bitstream filters as requested by the muxer." = lib.AVFMT_FLAG_AUTO_BSF


cdef class Container:
    def __cinit__(self, sentinel, file_, format_name, options,
                  container_options, stream_options,
                  metadata_encoding, metadata_errors,
                  buffer_size, open_timeout, read_timeout,
                  io_open):

        if sentinel is not _cinit_sentinel:
            raise RuntimeError("cannot construct base Container")

        self.writeable = isinstance(self, OutputContainer)
        if not self.writeable and not isinstance(self, InputContainer):
            raise RuntimeError("Container cannot be directly extended.")

        if isinstance(file_, str):
            self.name = file_
        else:
            self.name = str(getattr(file_, "name", "<none>"))

        self.options = dict(options or ())
        self.container_options = dict(container_options or ())
        self.stream_options = [dict(x) for x in stream_options or ()]

        self.metadata_encoding = metadata_encoding
        self.metadata_errors = metadata_errors

        self.open_timeout = open_timeout
        self.read_timeout = read_timeout

        self.buffer_size = buffer_size
        self.io_open = io_open

        if format_name is not None:
            self.format = ContainerFormat(format_name)

        self.input_was_opened = False
        cdef int res

        cdef bytes name_obj = os.fsencode(self.name)
        cdef char *name = name_obj

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
        self.ptr.opaque = <void*>self

        # Setup Python IO.
        self.open_files = {}
        if not isinstance(file_, basestring):
            self.file = PyIOFile(file_, buffer_size, self.writeable)
            self.ptr.pb = self.file.iocontext

        if io_open is not None:
            self.ptr.io_open = pyav_io_open
            self.ptr.io_close2 = pyav_io_close
            self.ptr.flags |= lib.AVFMT_FLAG_CUSTOM_IO

        cdef lib.AVInputFormat *ifmt
        cdef _Dictionary c_options
        if not self.writeable:
            ifmt = self.format.iptr if self.format else NULL
            c_options = Dictionary(self.options, self.container_options)

            self.set_timeout(self.open_timeout)
            self.start_timeout()
            with nogil:
                res = lib.avformat_open_input(&self.ptr, name, ifmt, &c_options.ptr)
            self.set_timeout(None)
            self.err_check(res)
            self.input_was_opened = True

        if format_name is None:
            self.format = build_container_format(self.ptr.iformat, self.ptr.oformat)

    def __dealloc__(self):
        with nogil:
            lib.avformat_free_context(self.ptr)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def __repr__(self):
        return f"<av.{self.__class__.__name__} {self.file or self.name!r}>"

    cdef int err_check(self, int value) except -1:
        return err_check(value, filename=self.name)

    def dumps_format(self):
        self._assert_open()
        with LogCapture() as logs:
            lib.av_dump_format(self.ptr, 0, "", isinstance(self, OutputContainer))
        return "".join(log[2] for log in logs)

    cdef set_timeout(self, timeout):
        if timeout is None:
            self.interrupt_callback_info.timeout = -1.0
        else:
            self.interrupt_callback_info.timeout = timeout

    cdef start_timeout(self):
        self.interrupt_callback_info.start_time = clock()

    cdef _assert_open(self):
        if self.ptr == NULL:
            raise AssertionError("Container is not open")

    @property
    def flags(self):
        self._assert_open()
        return self.ptr.flags

    @flags.setter
    def flags(self, int value):
        self._assert_open()
        self.ptr.flags = value

def open(
    file,
    mode=None,
    format=None,
    options=None,
    container_options=None,
    stream_options=None,
    metadata_encoding="utf-8",
    metadata_errors="strict",
    buffer_size=32768,
    timeout=None,
    io_open=None,
):
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
        ``(open timeout, read timeout)`` tuple.
    :param callable io_open: Custom I/O callable for opening files/streams.
        This option is intended for formats that need to open additional
        file-like objects to ``file`` using custom I/O.
        The callable signature is ``io_open(url: str, flags: int, options: dict)``, where
        ``url`` is the url to open, ``flags`` is a combination of AVIO_FLAG_* and
        ``options`` is a dictionary of additional options. The callable should return a
        file-like object.
    :rtype: Container

    For devices (via ``libavdevice``), pass the name of the device to ``format``,
    e.g.::

        >>> # Open webcam on MacOS.
        >>> av.open('0', format='avfoundation') # doctest: +SKIP

    For DASH and custom I/O using ``io_open``, add a protocol prefix to the ``file`` to
    prevent the DASH encoder defaulting to the file protocol and using temporary files.
    The custom I/O callable can be used to remove the protocol prefix to reveal the actual
    name for creating the file-like object. E.g.::

        >>> av.open("customprotocol://manifest.mpd", "w", io_open=custom_io) # doctest: +SKIP

    .. seealso:: :ref:`garbage_collection`

    More information on using input and output devices is available on the
    `FFmpeg website <https://www.ffmpeg.org/ffmpeg-devices.html>`_.
    """

    if not (mode is None or (isinstance(mode, str) and mode == "r" or mode == "w")):
        raise ValueError(f"mode must be 'r', 'w', or None, got: {mode}")

    if isinstance(file, str):
        pass
    elif isinstance(file, Path):
        file = f"{file}"
    elif mode is None:
        mode = getattr(file, "mode", None)

    if mode is None:
        mode = "r"

    if isinstance(timeout, tuple):
        if not len(timeout) == 2:
            raise ValueError("timeout must be `float` or `tuple[float, float]`")

        open_timeout, read_timeout = timeout
    else:
        open_timeout = timeout
        read_timeout = timeout

    if mode.startswith("r"):
        return InputContainer(_cinit_sentinel, file, format, options,
            container_options, stream_options, metadata_encoding, metadata_errors,
            buffer_size, open_timeout, read_timeout, io_open,
        )

    if stream_options:
        raise ValueError(
            "Provide stream options via Container.add_stream(..., options={})."
        )
    return OutputContainer(_cinit_sentinel, file, format, options,
        container_options, stream_options, metadata_encoding, metadata_errors,
        buffer_size, open_timeout, read_timeout, io_open,
    )
