from libc.stdint cimport uint8_t, int64_t
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy

import sys

cimport libav as lib

from av.container.input cimport InputContainer
from av.container.output cimport OutputContainer
from av.format cimport build_container_format
from av.utils cimport err_check, stash_exception, dict_to_avdict

from av.dictionary import Dictionary # not cimport
from av.utils import AVError # not cimport


cdef int pyio_read(void *opaque, uint8_t *buf, int buf_size) nogil:
    with gil:
        return pyio_read_gil(opaque, buf, buf_size)

cdef int pyio_read_gil(void *opaque, uint8_t *buf, int buf_size):
    cdef ContainerProxy self
    cdef bytes res
    try:
        self = <ContainerProxy>opaque
        res = self.fread(buf_size)
        memcpy(buf, <void*><char*>res, len(res))
        self.pos += len(res)
        if not res:
            return lib.AVERROR_EOF
        return len(res)
    except Exception as e:
        return stash_exception()


cdef int pyio_write(void *opaque, uint8_t *buf, int buf_size) nogil:
    with gil:
        return pyio_write_gil(opaque, buf, buf_size)

cdef int pyio_write_gil(void *opaque, uint8_t *buf, int buf_size):
    cdef ContainerProxy self
    cdef bytes bytes_to_write
    cdef int bytes_written
    try:
        self = <ContainerProxy>opaque
        bytes_to_write = buf[:buf_size]
        ret_value = self.fwrite(bytes_to_write)
        bytes_written = ret_value if isinstance(ret_value, int) else buf_size
        self.pos += bytes_written
        return bytes_written
    except Exception as e:
        return stash_exception()


cdef int64_t pyio_seek(void *opaque, int64_t offset, int whence) nogil:
    # Seek takes the standard flags, but also a ad-hoc one which means that
    # the library wants to know how large the file is. We are generally
    # allowed to ignore this.
    if whence == lib.AVSEEK_SIZE:
        return -1
    with gil:
        return pyio_seek_gil(opaque, offset, whence)

cdef int64_t pyio_seek_gil(void *opaque, int64_t offset, int whence):
    cdef ContainerProxy self
    try:
        self = <ContainerProxy>opaque
        res = self.fseek(offset, whence)

        # Track the position for the user.
        if whence == 0:
            self.pos = offset
        elif whence == 1:
            self.pos += offset
        else:
            self.pos_is_valid = False
        if res is None:
            if self.pos_is_valid:
                res = self.pos
            else:
                res = self.ftell()
        return res

    except Exception as e:
        return stash_exception()



cdef object _cinit_sentinel = object()



cdef class ContainerProxy(object):

    def __init__(self, sentinel, Container container):

        cdef int res

        if sentinel is not _cinit_sentinel:
            raise RuntimeError('cannot construct ContainerProxy')

        # Copy key attributes.
        self.name = container.name
        self.file = container.file
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
            #self.ptr.flags = lib.AVFMT_FLAG_CUSTOM_IO

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

    def __dealloc__(self):
        with nogil:

            # Let FFmpeg handle it if it fully opened.
            if self.ptr and not self.writeable:
                lib.avformat_close_input(&self.ptr)

            # Manually free things.
            else:
                if self.buffer:
                    lib.av_freep(&self.buffer)
                if self.iocontext:
                    lib.av_freep(&self.iocontext)

    cdef seek(self, int stream_index, lib.int64_t timestamp, str mode, bint backward, bint any_frame):

        cdef int flags = 0
        cdef int ret

        if mode == 'frame':
            flags |= lib.AVSEEK_FLAG_FRAME
        elif mode == 'byte':
            flags |= lib.AVSEEK_FLAG_BYTE
        elif mode != 'time':
            raise ValueError('mode must be one of "frame", "byte", or "time"')

        if backward:
            flags |= lib.AVSEEK_FLAG_BACKWARD

        if any_frame:
            flags |= lib.AVSEEK_FLAG_ANY

        with nogil:
            ret = lib.av_seek_frame(self.ptr, stream_index, timestamp, flags)
        err_check(ret)

        self.flush_buffers()

    cdef flush_buffers(self):
        cdef int i
        cdef lib.AVStream *stream

        with nogil:
            for i in range(self.ptr.nb_streams):
                stream = self.ptr.streams[i]
                if stream.codec and stream.codec.codec_id != lib.AV_CODEC_ID_NONE:
                    lib.avcodec_flush_buffers(stream.codec)


    cdef int err_check(self, int value) except -1:
        return err_check(value, filename=self.name)



cdef class Container(object):

    def __cinit__(self, sentinel, file_, format_name, options):

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

        self.proxy = ContainerProxy(_cinit_sentinel, self)

        if format_name is None:
            self.format = build_container_format(self.proxy.ptr.iformat, self.proxy.ptr.oformat)

    def __repr__(self):
        return '<av.%s %r>' % (self.__class__.__name__, self.file or self.name)



def open(file, mode=None, format=None, options=None):
    """open(file, mode='r', format=None, options=None)

    Main entrypoint to opening files/streams.

    :param str file: The file to open.
    :param str mode: ``"r"`` for reading and ``"w"`` for writing.
    :param str format: Specific format to use. Defaults to autodect.
    :param dict options: Options to pass to the container and streams.

    For devices (via `libavdevice`), pass the name of the device to ``format``,
    e.g.::

        >>> # Open webcam on OS X.
        >>> av.open(format='avfoundation', file='0') # doctest: SKIP

    """

    if mode is None:
        mode = getattr(file, 'mode', None)
    if mode is None:
        mode = 'r'

    if mode.startswith('r'):
        return InputContainer(_cinit_sentinel, file, format, options)
    if mode.startswith('w'):
        return OutputContainer(_cinit_sentinel, file, format, options)
    raise ValueError("mode must be 'r' or 'w'; got %r" % mode)
