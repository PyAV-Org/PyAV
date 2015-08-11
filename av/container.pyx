from libc.stdint cimport uint8_t, int64_t
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy

import sys
from fractions import Fraction

cimport libav as lib

from av.format cimport build_container_format
from av.packet cimport Packet
from av.stream cimport Stream, build_stream
from av.utils cimport err_check, stash_exception, avdict_to_dict, dict_to_avdict

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
    cdef str str_to_write
    cdef int bytes_written
    try:
        self = <ContainerProxy>opaque
        str_to_write = buf[:buf_size]
        ret_value = self.fwrite(str_to_write)
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


cdef object _base_constructor_sentinel = object()


cdef class ContainerProxy(object):

    def __init__(self, sentinel, Container container):

        cdef int res

        if sentinel is not _base_constructor_sentinel:
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
        if not self.writeable:
            ifmt = container.format.iptr if container.format else NULL
            with nogil:
                res = lib.avformat_open_input(
                    &self.ptr,
                    name,
                    ifmt,
                    &container.options if container.options else NULL
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
        return InputContainer(_base_constructor_sentinel, file, format, options)
    if mode.startswith('w'):
        return OutputContainer(_base_constructor_sentinel, file, format, options)
    raise ValueError("mode must be 'r' or 'w'; got %r" % mode)


cdef class Container(object):

    def __cinit__(self, sentinel, file_, format_name, options):

        if sentinel is not _base_constructor_sentinel:
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

        if options is not None:
            dict_to_avdict(&self.options, options)

        self.proxy = ContainerProxy(_base_constructor_sentinel, self)

        if format_name is None:
            self.format = build_container_format(self.proxy.ptr.iformat, self.proxy.ptr.oformat)

    def __dealloc__(self):
        with nogil:
            lib.av_dict_free(&self.options)

    def __repr__(self):
        return '<av.%s %r>' % (self.__class__.__name__, self.file or self.name)


cdef class InputContainer(Container):
    
    def __cinit__(self, *args, **kwargs):

        with nogil:
            ret = lib.avformat_find_stream_info(
                self.proxy.ptr,
                # Our understanding is that there is little overlap bettween
                # options for containers and streams, so we use the same dict.
                # Possible TODO: expose per-stream options.
                &self.options if self.options else NULL
            )
        self.proxy.err_check(ret)

        self.streams = list(
            build_stream(self, self.proxy.ptr.streams[i])
            for i in range(self.proxy.ptr.nb_streams)
        )
        self.metadata = avdict_to_dict(self.proxy.ptr.metadata)

    property start_time:
        def __get__(self): return self.proxy.ptr.start_time
    
    property duration:
        def __get__(self): return self.proxy.ptr.duration
    
    property bit_rate:
        def __get__(self): return self.proxy.ptr.bit_rate

    property size:
        def __get__(self): return lib.avio_size(self.proxy.ptr.pb)

    def demux(self, streams=None):
        """demux(streams=None)

        Yields a series of :class:`.Packet` from the given set of :class:`.Stream`

        The last packets are dummy packets that when decoded will flush the buffers.

        """
        
        streams = streams or self.streams
        if isinstance(streams, Stream):
            streams = (streams, )

        cdef bint *include_stream = <bint*>malloc(self.proxy.ptr.nb_streams * sizeof(bint))
        if include_stream == NULL:
            raise MemoryError()
        
        cdef int i
        cdef Packet packet
        cdef int ret

        try:
            
            for i in range(self.proxy.ptr.nb_streams):
                include_stream[i] = False
            for stream in streams:
                include_stream[stream.index] = True
        
            while True:
                
                packet = Packet()
                try:
                    with nogil:
                        ret = lib.av_read_frame(self.proxy.ptr, &packet.struct)
                    self.proxy.err_check(ret)
                except AVError:
                    break
                    
                if include_stream[packet.struct.stream_index]:
                    # If AVFMTCTX_NOHEADER is set in ctx_flags, then new streams 
                    # may also appear in av_read_frame().
                    # http://ffmpeg.org/doxygen/trunk/structAVFormatContext.html
                    # TODO: find better way to handle this 
                    if packet.struct.stream_index < len(self.streams):
                        packet.stream = self.streams[packet.struct.stream_index]
                        yield packet

            # Flush!
            for i in range(self.proxy.ptr.nb_streams):
                if include_stream[i]:
                    packet = Packet()
                    packet.stream = self.streams[i]
                    yield packet

        finally:
            free(include_stream)
            
    def seek(self, timestamp, mode='time', backward=True, any_frame=False):
        """Seek to the keyframe at the given timestamp.

        :param int timestamp: time in AV_TIME_BASE units.
        :param str mode: one of ``"backward"``, ``"frame"``, ``"byte"``, or ``"any"``.

        """
        if isinstance(timestamp, float):
            timestamp = <long>(timestamp * lib.AV_TIME_BASE)
        self.proxy.seek(-1, timestamp, mode, backward, any_frame)


cdef class OutputContainer(Container):

    def __cinit__(self, *args, **kwargs):
        self.streams = []
        self.metadata = {}

    def __del__(self):
        self.close()

    cpdef add_stream(self, codec_name=None, object rate=None, Stream template=None):
        """add_stream(codec_name, rate=None)

        Create a new stream, and return it.

        :param str codec_name: The name of a codec.
        :param rate: The frame rate for video, and sample rate for audio.
            Examples for video include ``24``, ``23.976``, and
            ``Fraction(30000,1001)``. Examples for audio include ``48000``
            and ``44100``.
        :returns: The new :class:`~av.stream.Stream`.

        """
        
        if (codec_name is None and template is None) or (codec_name is not None and template is not None):
            raise ValueError('needs one of codec_name or template')

        cdef lib.AVCodec *codec
        cdef lib.AVCodecDescriptor *codec_descriptor

        if codec_name is not None:
            codec = lib.avcodec_find_encoder_by_name(codec_name)
            if not codec:
                codec_descriptor = lib.avcodec_descriptor_get_by_name(codec_name)
                if codec_descriptor:
                    codec = lib.avcodec_find_encoder(codec_descriptor.id)
            if not codec:
                raise ValueError("unknown encoding codec: %r" % codec_name)
        else:
            if not template._codec:
                raise ValueError("template has no codec")
            if not template._codec_context:
                raise ValueError("template has no codec context")
            codec = template._codec
        
        # Assert that this format supports the requested codec.
        if not lib.avformat_query_codec(
            self.proxy.ptr.oformat,
            codec.id,
            lib.FF_COMPLIANCE_NORMAL,
        ):
            raise ValueError("%r format does not support %r codec" % (self.format.name, codec_name))

        # Create new stream in the AVFormatContext, set AVCodecContext values.
        lib.avformat_new_stream(self.proxy.ptr, codec)
        cdef lib.AVStream *stream = self.proxy.ptr.streams[self.proxy.ptr.nb_streams - 1]
        cdef lib.AVCodecContext *codec_context = stream.codec # For readibility.
        lib.avcodec_get_context_defaults3(stream.codec, codec)
        stream.codec.codec = codec # Still have to manually set this though...

        # Copy from the template.
        if template is not None:

            # Video properties (from below).
            codec_context.time_base.num = template._codec_context.time_base.num
            codec_context.time_base.den = template._codec_context.time_base.den
            codec_context.pix_fmt = template._codec_context.pix_fmt
            codec_context.width = template._codec_context.width
            codec_context.height = template._codec_context.height
            codec_context.bit_rate = template._codec_context.bit_rate
            codec_context.bit_rate_tolerance = template._codec_context.bit_rate_tolerance
            codec_context.ticks_per_frame = template._codec_context.ticks_per_frame
            # From <https://stackoverflow.com/questions/17592120>
            stream.sample_aspect_ratio.num = template._stream.sample_aspect_ratio.num
            stream.sample_aspect_ratio.den = template._stream.sample_aspect_ratio.den
            stream.time_base.num = template._stream.time_base.num
            stream.time_base.den = template._stream.time_base.den
            stream.avg_frame_rate.num = template._stream.avg_frame_rate.num
            stream.avg_frame_rate.den = template._stream.avg_frame_rate.den
            stream.duration = template._stream.duration
            # More that we believe are nessesary.
            codec_context.sample_aspect_ratio.num = template._codec_context.sample_aspect_ratio.num
            codec_context.sample_aspect_ratio.den = template._codec_context.sample_aspect_ratio.den

            # Audio properties (from defaults below that don't overlap above).
            codec_context.sample_fmt = template._codec_context.sample_fmt
            codec_context.sample_rate = template._codec_context.sample_rate
            codec_context.channels = template._codec_context.channels
            codec_context.channel_layout = template._codec_context.channel_layout
            # From <https://stackoverflow.com/questions/17592120>
            stream.pts = template._stream.pts

        # Now lets set some more sane video defaults
        elif codec.type == lib.AVMEDIA_TYPE_VIDEO:
            codec_context.pix_fmt = lib.AV_PIX_FMT_YUV420P
            codec_context.width = 640
            codec_context.height = 480
            codec_context.bit_rate = 1024000
            codec_context.bit_rate_tolerance = 128000
            codec_context.ticks_per_frame = 1

            rate = Fraction(rate or 24)
            codec_context.time_base.num = rate.denominator
            codec_context.time_base.den = rate.numerator

            # TODO: Should this be inverted from the rate?
            stream.time_base.num = rate.denominator
            stream.time_base.den = rate.numerator

        # Some sane audio defaults
        elif codec.type == lib.AVMEDIA_TYPE_AUDIO:
            codec_context.sample_fmt = codec.sample_fmts[0]
            codec_context.bit_rate = 128000
            codec_context.bit_rate_tolerance = 32000
            codec_context.sample_rate = rate or 48000
            codec_context.channels = 2
            codec_context.channel_layout = lib.AV_CH_LAYOUT_STEREO

            # TODO: Should this be inverted from the rate?
            stream.time_base.num = 1
            stream.time_base.den = codec_context.sample_rate

        # Some formats want stream headers to be separate
        if self.proxy.ptr.oformat.flags & lib.AVFMT_GLOBALHEADER:
            codec_context.flags |= lib.CODEC_FLAG_GLOBAL_HEADER
        
        # Finally construct the user-land stream.
        cdef Stream py_stream = build_stream(self, stream)
        self.streams.append(py_stream)
        return py_stream
    
    cpdef start_encoding(self):
        """Write the file header! Called automatically."""
        
        if self._started:
            return

        # Make sure all of the streams are open.
        cdef Stream stream
        for stream in self.streams:
            if not lib.avcodec_is_open(stream._codec_context):
                self.proxy.err_check(lib.avcodec_open2(
                    stream._codec_context,
                    stream._codec,
                    # Our understanding is that there is little overlap bettween
                    # options for containers and streams, so we use the same dict.
                    # Possible TODO: expose per-stream options.
                    &self.options if self.options else NULL
                ))
            dict_to_avdict(&stream._stream.metadata, stream.metadata, clear=True)

        # Open the output file, if needed.
        # TODO: is the avformat_write_header in the right place here?
        cdef char *name = "" if self.proxy.file is not None else self.name

        if self.proxy.ptr.pb == NULL and not self.proxy.ptr.oformat.flags & lib.AVFMT_NOFILE:
            err_check(lib.avio_open(&self.proxy.ptr.pb, name, lib.AVIO_FLAG_WRITE))

        dict_to_avdict(&self.proxy.ptr.metadata, self.metadata, clear=True)
        self.proxy.err_check(lib.avformat_write_header(
            self.proxy.ptr, 
            &self.options if self.options else NULL
        ))

        self._started = True
            
    def close(self):

        if self._done:
            return
        if not self._started:
            raise RuntimeError('not started')
        if not self.proxy.ptr.pb:
            raise IOError("file not opened")
        
        self.proxy.err_check(lib.av_write_trailer(self.proxy.ptr))
        cdef Stream stream
        for stream in self.streams:
            lib.avcodec_close(stream._codec_context)
            
        if self.file is None and not self.proxy.ptr.oformat.flags & lib.AVFMT_NOFILE:
            lib.avio_closep(&self.proxy.ptr.pb)

        self._done = True
        
    def mux(self, Packet packet not None):
        self.start_encoding()
        self.proxy.err_check(lib.av_interleaved_write_frame(self.proxy.ptr, &packet.struct))


    