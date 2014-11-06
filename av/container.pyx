from libc.stdint cimport uint8_t, int64_t
from libc.stdlib cimport malloc, free

cimport libav as lib

from av.format cimport build_container_format
from av.packet cimport Packet
from av.stream cimport Stream, build_stream
from av.utils cimport err_check, avdict_to_dict, dict_to_avdict

from fractions import Fraction

from av.utils import AVError


cdef class ContainerProxy(object):
    # Just a reference-counting wrapper for a pointer.
    def __dealloc__(self):
        if self.ptr and self.ptr.iformat:
            with nogil: lib.avformat_close_input(&self.ptr)

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


cdef object _base_constructor_sentinel = object()

def open(name, mode='r', format=None, options=None):
    if mode == 'r':
        return InputContainer(_base_constructor_sentinel, name, format, options)
    if mode == 'w':
        return OutputContainer(_base_constructor_sentinel, name, format, options)
    raise ValueError("mode must be 'r' or 'w'; got %r" % mode)


cdef class Container(object):

    def __cinit__(self, sentinel, name, format_name, options):

        if sentinel is not _base_constructor_sentinel:
            raise RuntimeError('cannot construct base Container')

        if format_name is not None:
            self.format = ContainerFormat(format_name)

        self.name = name
        self.proxy = ContainerProxy()

        if options is not None:
            dict_to_avdict(&self.options, options)

    def __dealloc__(self):
        with nogil: lib.av_dict_free(&self.options)

    def __repr__(self):
        return '<av.%s %r>' % (self.__class__.__name__, self.name)

cdef class InputContainer(Container):
    
    def __cinit__(self, *args, **kwargs):

        cdef char *name = self.name
        cdef lib.AVInputFormat *fmt = NULL
        if self.format:
            fmt = self.format.in_
        with nogil:
            ret = lib.avformat_open_input(
                    &self.proxy.ptr,
                    name,
                    fmt,
                    &self.options if self.options else NULL
                )
            with gil: err_check(ret, self.name)
            ret = lib.avformat_find_stream_info(self.proxy.ptr, NULL)
        err_check(ret)

        self.format = self.format or build_container_format(self.proxy.ptr.iformat, self.proxy.ptr.oformat)

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
        """Yields a series of :class:`.Packet` from the given set of :class:`.Stream`

        The last packet is a dummy packet, that when decoded will flush the buffers.

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
                    err_check(ret)
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

        cdef lib.AVOutputFormat* format = self.format.out if self.format else lib.av_guess_format(NULL, self.name, NULL)
        if not format:
            raise ValueError("Could not deduce output format")

        err_check(lib.avformat_alloc_output_context2(
            &self.proxy.ptr,
            format,
            NULL,
            self.name,
        ))

        self.format = self.format or build_container_format(self.proxy.ptr.iformat, self.proxy.ptr.oformat)
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
            # From SO <https://stackoverflow.com/questions/17592120>
            stream.sample_aspect_ratio.num = template._stream.sample_aspect_ratio.num
            stream.sample_aspect_ratio.den = template._stream.sample_aspect_ratio.den
            stream.time_base.num = template._stream.time_base.num
            stream.time_base.den = template._stream.time_base.den
            stream.avg_frame_rate.num = template._stream.avg_frame_rate.num
            stream.avg_frame_rate.den = template._stream.avg_frame_rate.den
            stream.duration = template._stream.duration
            # More.
            codec_context.sample_aspect_ratio.num = template._codec_context.sample_aspect_ratio.num
            codec_context.sample_aspect_ratio.den = template._codec_context.sample_aspect_ratio.den

            # Audio properties (from below that don't overlap above).
            codec_context.sample_fmt = template._codec_context.sample_fmt
            codec_context.sample_rate = template._codec_context.sample_rate
            codec_context.channels = template._codec_context.channels
            codec_context.channel_layout = template._codec_context.channel_layout
            # From SO <https://stackoverflow.com/questions/17592120>
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

        # Some Sane audio defaults
        elif codec.type == lib.AVMEDIA_TYPE_AUDIO:
            codec_context.sample_fmt = codec.sample_fmts[0]
            codec_context.bit_rate = 128000
            codec_context.bit_rate_tolerance = 32000
            codec_context.sample_rate = rate or 48000
            codec_context.channels = 2
            codec_context.channel_layout = lib.AV_CH_LAYOUT_STEREO

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
                err_check(lib.avcodec_open2(stream._codec_context, stream._codec, NULL))
            dict_to_avdict(&stream._stream.metadata, stream.metadata, clear=True)

        # Open the output file, if needed.
        # TODO: is the avformat_write_header in the right place here?
        if not self.proxy.ptr.pb:
            if not self.proxy.ptr.oformat.flags & lib.AVFMT_NOFILE:
                err_check(lib.avio_open(&self.proxy.ptr.pb, self.name, lib.AVIO_FLAG_WRITE))
            dict_to_avdict(&self.proxy.ptr.metadata, self.metadata, clear=True)
            err_check(lib.avformat_write_header(self.proxy.ptr, NULL))

        self._started = True
            
    def close(self):

        if self._done:
            return
        if not self._started:
            raise RuntimeError('not started')
        if not self.proxy.ptr.pb:
            raise IOError("file not opened")
        
        err_check(lib.av_write_trailer(self.proxy.ptr))
        cdef Stream stream
        for stream in self.streams:
            lib.avcodec_close(stream._codec_context)
            
        if not self.proxy.ptr.oformat.flags & lib.AVFMT_NOFILE:
            lib.avio_closep(&self.proxy.ptr.pb)

        self._done = True
        
    def mux(self, Packet packet not None):
        self.start_encoding()
        err_check(lib.av_interleaved_write_frame(self.proxy.ptr, &packet.struct))


