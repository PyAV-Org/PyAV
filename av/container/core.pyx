from libc.stdint cimport int64_t
from libc.stdlib cimport malloc, free

import sys

cimport libav as lib

from av.container.input cimport InputContainer
from av.container.output cimport OutputContainer
from av.container.pyio cimport pyio_read, pyio_write, pyio_seek
from av.format cimport build_container_format
from av.utils cimport err_check, dict_to_avdict

from av.dictionary import Dictionary # not cimport
from av.logging import Capture as LogCapture # not cimport
from av.utils import AVError # not cimport

try:
    from os import fsencode
except ImportError:
    _fsencoding = sys.getfilesystemencoding()
    fsencode = lambda s: s.encode(_fsencoding)



cdef object _cinit_sentinel = object()



cdef class ContainerProxy(object):

    def __init__(self, sentinel, Container container):

        self.input_was_opened = False
        cdef int res

        if sentinel is not _cinit_sentinel:
            raise RuntimeError('cannot construct ContainerProxy')

        # Copy key attributes.
        self.file = container.file
        self.metadata_encoding = container.metadata_encoding
        self.metadata_errors = container.metadata_errors
        self.name = container.name
        self.writeable = container.writeable

        cdef bytes name_obj = fsencode(self.name) if isinstance(self.name, unicode) else self.name
        cdef char *name = name_obj

        cdef lib.AVOutputFormat *ofmt
        if self.writeable:

            ofmt = container.format.optr if container.format else lib.av_guess_format(NULL, name, NULL)
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

        self.ptr.flags |= lib.AVFMT_FLAG_GENPTS
        self.ptr.max_analyze_duration = 10000000

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

            self.pos = 0
            self.pos_is_valid = True

            # This is effectively the maximum size of reads.
            self.bufsize = 32 * 1024
            self.buffer = <unsigned char*>lib.av_malloc(self.bufsize)

            self.iocontext = lib.avio_alloc_context(
                self.buffer, self.bufsize,
                self.writeable, # Writeable.
                <void*>self, # User data.
                pyio_read,
                pyio_write,
                pyio_seek
            )

            if self.fseek is not None and self.ftell is not None:
                self.iocontext.seekable = lib.AVIO_SEEKABLE_NORMAL
            self.iocontext.max_packet_size = self.bufsize
            self.ptr.pb = self.iocontext

        cdef lib.AVInputFormat *ifmt
        cdef _Dictionary options
        if not self.writeable:
            ifmt = container.format.iptr if container.format else NULL
            
            options = Dictionary(container.options, container.container_options)
            with nogil:
                res = lib.avformat_open_input(
                    &self.ptr,
                    name,
                    ifmt,
                    &options.ptr
                )
            self.err_check(res)
            self.input_was_opened = True

    def __dealloc__(self):
        with nogil:

            # Let FFmpeg close input if it was fully opened.
            if self.input_was_opened:
                lib.avformat_close_input(&self.ptr)

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

    cdef seek(self, int stream_index, offset, str whence, bint backward, bint any_frame):

        # We used to take floats here and assume they were in seconds. This
        # was super confusing, so lets go in the complete opposite direction.
        if not isinstance(offset, (int, long)):
            raise TypeError('Container.seek only accepts integer offset.', type(offset))
        cdef int64_t c_offset = offset

        cdef int flags = 0
        cdef int ret

        if whence == 'frame':
            flags |= lib.AVSEEK_FLAG_FRAME
        elif whence == 'byte':
            flags |= lib.AVSEEK_FLAG_BYTE
        elif whence != 'time':
            raise ValueError("whence must be one of 'frame', 'byte', or 'time'.", whence)

        if backward:
            flags |= lib.AVSEEK_FLAG_BACKWARD

        if any_frame:
            flags |= lib.AVSEEK_FLAG_ANY

        with nogil:
            ret = lib.av_seek_frame(self.ptr, stream_index, c_offset, flags)
        err_check(ret)

        self.flush_buffers()

    cdef flush_buffers(self):
        cdef int i
        cdef lib.AVStream *stream

        with nogil:
            for i in range(self.ptr.nb_streams):
                stream = self.ptr.streams[i]
                if stream.codec and stream.codec.codec and stream.codec.codec_id != lib.AV_CODEC_ID_NONE:
                    lib.avcodec_flush_buffers(stream.codec)


    cdef int err_check(self, int value) except -1:
        return err_check(value, filename=self.name)



cdef class Container(object):

    def __cinit__(self, sentinel, file_, format_name, options, container_options, stream_options, metadata_encoding, metadata_errors):

        if sentinel is not _cinit_sentinel:
            raise RuntimeError('cannot construct base Container')

        self.writeable = isinstance(self, OutputContainer)
        if not self.writeable and not isinstance(self, InputContainer):
            raise RuntimeError('Container cannot be extended except')

        if isinstance(file_, basestring):
            self.name = file_
        else:
            self.name = getattr(file_, 'name', '<none>')
            if not isinstance(self.name, basestring):
                raise TypeError("File's name attribute must be string-like.")
            self.file = file_

        if format_name is not None:
            self.format = ContainerFormat(format_name)

        self.options = dict(options or ())
        self.container_options = dict(container_options or ())
        self.stream_options = [dict(x) for x in stream_options or ()]

        self.metadata_encoding = metadata_encoding
        self.metadata_errors = metadata_errors
        self.proxy = ContainerProxy(_cinit_sentinel, self)

        if format_name is None:
            self.format = build_container_format(self.proxy.ptr.iformat, self.proxy.ptr.oformat)

    def __repr__(self):
        return '<av.%s %r>' % (self.__class__.__name__, self.file or self.name)

    def dumps_format(self):
        with LogCapture() as logs:
            lib.av_dump_format(self.proxy.ptr, 0, "", isinstance(self, OutputContainer))
        return ''.join(log[2] for log in logs)



def open(file, mode=None, format=None, options=None,
    container_options=None, stream_options=None,
    metadata_encoding=None, metadata_errors='strict'):
    """open(file, mode='r', format=None, options=None, metadata_encoding=None, metadata_errors='strict')

    Main entrypoint to opening files/streams.

    :param str file: The file to open.
    :param str mode: ``"r"`` for reading and ``"w"`` for writing.
    :param str format: Specific format to use. Defaults to autodect.
    :param dict options: Options to pass to the container and all streams.
    :param dict container_options: Options to pass to the container.
    :param list stream_options: Options to pass to each stream.
    :param str metadata_encoding: Encoding to use when reading or writing file metadata.
        Defaults to utf-8, except no decoding is performed by default when
        reading on Python 2 (returning ``str`` instead of ``unicode``).
    :param str metadata_errors: Specifies how to handle encoding errors; behaves like
        ``str.encode`` parameter. Defaults to strict.

    For devices (via ``libavdevice``), pass the name of the device to ``format``,
    e.g.::

        >>> # Open webcam on OS X.
        >>> av.open(format='avfoundation', file='0') # doctest: +SKIP

    """

    if mode is None:
        mode = getattr(file, 'mode', None)
    if mode is None:
        mode = 'r'

    if mode.startswith('r'):
        return InputContainer(_cinit_sentinel, file, format, options,
            container_options, stream_options,
            metadata_encoding, metadata_errors
        )
    if mode.startswith('w'):
        if stream_options:
            raise ValueError("Provide stream options via Container.add_stream(..., options={}).")
        return OutputContainer(_cinit_sentinel, file, format, options,
            container_options, stream_options,
            metadata_encoding, metadata_errors
        )
    raise ValueError("mode must be 'r' or 'w'; got %r" % mode)
