from libc.stdint cimport uint8_t, int64_t
from libc.stdlib cimport malloc, free

cimport libav as lib

from av.format cimport build_container_format
from av.packet cimport Packet
from av.stream cimport Stream, build_stream
from av.utils cimport err_check, avdict_to_dict
from av.utils import AVError


cdef class ContainerProxy(object):
    # Just a reference-counting wrapper for a pointer.
    def __dealloc__(self):
        if self.ptr and self.ptr.iformat:
            lib.avformat_close_input(&self.ptr)


cdef object _base_constructor_sentinel = object()

def open(name, mode='r'):
    if mode == 'r':
        return InputContainer(_base_constructor_sentinel, name)
    if mode == 'w':
        return OutputContainer(_base_constructor_sentinel, name)
    raise ValueError("mode must be 'r' or 'w'; got %r" % mode)


cdef class Container(object):

    def __cinit__(self, sentinel, name):
        if sentinel is not _base_constructor_sentinel:
            raise RuntimeError('cannot construct base Container')
        self.name = name
        self.proxy = ContainerProxy()

    def __repr__(self):
        return '<av.%s %r>' % (self.__class__.__name__, self.name)


cdef class InputContainer(object):
    
    def __cinit__(self, *args, **kwargs):
        err_check(
            lib.avformat_open_input(&self.proxy.ptr, self.name, NULL, NULL),
            self.name,
        )
        err_check(lib.avformat_find_stream_info(self.proxy.ptr, NULL))
        self.format = build_container_format(self.proxy.ptr.iformat, self.proxy.ptr.oformat)
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

    def demux(self, streams=None):
        
        streams = streams or self.streams
        if isinstance(streams, Stream):
            streams = (streams, )

        cdef bint *include_stream = <bint*>malloc(self.proxy.ptr.nb_streams * sizeof(bint))
        if include_stream == NULL:
            raise MemoryError()
        
        cdef int i
        cdef Packet packet

        try:
            
            for i in range(self.proxy.ptr.nb_streams):
                include_stream[i] = False
            for stream in streams:
                include_stream[stream.index] = True
        
            while True:
                packet = Packet()
                try:
                    err_check(lib.av_read_frame(self.proxy.ptr, &packet.struct))
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

        finally:
            free(include_stream)


cdef class OutputContainer(object):

    def __cinit__(self, *args, **kwargs):

        cdef lib.AVOutputFormat* container_format = lib.av_guess_format(NULL, self.name, NULL)
        if not container_format:
            raise ValueError("Could not deduce output format")

        err_check(lib.avformat_alloc_output_context2(
            &self.proxy.ptr,
            container_format,
            NULL,
            self.name,
        ))

        self.format = build_container_format(self.proxy.ptr.iformat, self.proxy.ptr.oformat)
        self.streams = []
        self.metadata = {}

    def __del__(self):
        self.close()

    cpdef add_stream(self, bytes codec_name, object rate=None):
        
        """Add stream to Container and return it.
        if the codec_name is a video codec rate means frames per second,
        if the codec_name is a audio codec rate means sample rate 
        Note: To use this Container must be opened with mode = "w"
        """
        
        # Find encoder
        cdef lib.AVCodec *codec
        cdef lib.AVCodecDescriptor *codec_descriptor
        codec = lib.avcodec_find_encoder_by_name(codec_name)
        if not codec:
            codec_descriptor = lib.avcodec_descriptor_get_by_name(codec_name)
            if codec_descriptor:
                codec = lib.avcodec_find_encoder(codec_descriptor.id)
        if not codec:
            raise ValueError("unknown encoding codec: %r" % codec_name)
        
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

        # Now lets set some more sane video defaults
        if codec.type == lib.AVMEDIA_TYPE_VIDEO:
            codec_context.time_base.num = 1
            codec_context.time_base.den = 12800 
            codec_context.pix_fmt = lib.AV_PIX_FMT_YUV420P
            codec_context.width = 640
            codec_context.height = 480
            codec_context.ticks_per_frame = 1
            codec_context.time_base.num = 1
            codec_context.time_base.den = rate or 24

        # Some Sane audio defaults
        elif codec.type == lib.AVMEDIA_TYPE_AUDIO:
            codec_context.sample_fmt = codec.sample_fmts[0]
            codec_context.bit_rate = 64000
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

        # Open the output file, if needed.
        # TODO: is the avformat_write_header in the right place here?
        if not self.proxy.ptr.pb:
            if not self.proxy.ptr.oformat.flags & lib.AVFMT_NOFILE:
                err_check(lib.avio_open(&self.proxy.ptr.pb, self.name, lib.AVIO_FLAG_WRITE))
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


