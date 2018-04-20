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
from av.utils import AVError # not cimport




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

        cdef char *name = self.name


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

            # TODO: Make sure we actually have these.
            self.fread = getattr(self.file, 'read', None)
            self.fwrite = getattr(self.file, 'write', None)
            self.fseek = getattr(self.file, 'seek', None)
            self.ftell = getattr(self.file, 'tell', None)

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
            # Various tutorials say that we should set AVFormatContext.direct
            # to AVIO_FLAG_DIRECT here, but that doesn't seem to do anything in
            # FFMpeg and was deprecated.
            self.iocontext.seekable = lib.AVIO_SEEKABLE_NORMAL
            self.iocontext.max_packet_size = self.bufsize
            self.ptr.pb = self.iocontext
            #self.ptr.flags |= lib.AVFMT_FLAG_CUSTOM_IO

        cdef lib.AVInputFormat *ifmt
        cdef _Dictionary options
        if not self.writeable:
            ifmt = container.format.iptr if container.format else NULL
            options = container.options.copy()
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

            # Let FFmpeg handle it if it fully opened.
            if self.input_was_opened:
                lib.avformat_close_input(&self.ptr)

            # If we didn't open as input, but the IOContext was created.
            # So either this is an output or we errored.
            # lib.avio_alloc_context says our buffer "may be freed and replaced with
            # a new buffer" so we should just leave it.
            elif self.iocontext:
                lib.av_freep(&self.iocontext.buffer)
                lib.av_freep(&self.iocontext)

            # We likely errored badly if we got here, and so are still
            # responsible for our buffer.
            else:
                lib.av_freep(&self.buffer)

            # To be safe, lets give it another chance to free the whole structure.
            # I (Mike) am not 100% on the deconstruction for output, and meshing
            # these two together. This is safe to call after the avformat_close_input
            # above, so *shrugs*.
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

    def __cinit__(self, sentinel, file_, format_name, options, metadata_encoding, metadata_errors):

        if sentinel is not _cinit_sentinel:
            raise RuntimeError('cannot construct base Container')

        self.writeable = isinstance(self, OutputContainer)
        if not self.writeable and not isinstance(self, InputContainer):
            raise RuntimeError('Container cannot be extended except')

        if isinstance(file_, basestring):
            self.name = file_
        else:
            self.name = str(getattr(file_, 'name', None))
            self.file = file_

        if format_name is not None:
            self.format = ContainerFormat(format_name)

        self.options = Dictionary(**(options or {}))

        self.metadata_encoding = metadata_encoding
        self.metadata_errors = metadata_errors
        self.proxy = ContainerProxy(_cinit_sentinel, self)

        if format_name is None:
            self.format = build_container_format(self.proxy.ptr.iformat, self.proxy.ptr.oformat)

    def __repr__(self):
        return '<av.%s %r>' % (self.__class__.__name__, self.file or self.name)



def open(file, mode=None, format=None, options=None, metadata_encoding=None, metadata_errors='strict'):
    """open(file, mode='r', format=None, options=None, metadata_encoding=None, metadata_errors='strict')

    Main entrypoint to opening files/streams.

    :param str file: The file to open.
    :param str mode: ``"r"`` for reading and ``"w"`` for writing.
    :param str format: Specific format to use. Defaults to autodect.
    :param dict options: Options to pass to the container and streams.
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
        return InputContainer(_cinit_sentinel, file, format, options, metadata_encoding, metadata_errors)
    if mode.startswith('w'):
        return OutputContainer(_cinit_sentinel, file, format, options, metadata_encoding, metadata_errors)
    raise ValueError("mode must be 'r' or 'w'; got %r" % mode)
