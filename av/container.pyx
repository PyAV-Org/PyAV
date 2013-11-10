from libc.stdint cimport uint8_t, int64_t
from libc.stdlib cimport malloc, free

cimport libav as lib

from av.packet cimport Packet
from av.stream cimport Stream, stream_factory
from av.utils cimport err_check, avdict_to_dict
from av.utils import AVError


cdef class ContainerProxy(object):

    def __init__(self, bint is_input):
        self.is_input = is_input
    
    def __dealloc__(self):
        if self.ptr != NULL:
            if self.is_input:
                lib.avformat_close_input(&self.ptr)



cdef class Container(object):

    def __init__(self, name, mode='r'):
        
        cdef lib.AVOutputFormat* fmt
        
        if mode == 'r':
            self.is_input = True
            self.is_output = False
        elif mode == 'w':
            self.is_input = False
            self.is_output = True
        else:
            raise ValueError('mode must be "r" or "w"')
        
        self.name = name
        self.mode = mode
        
        self.proxy = ContainerProxy(self.is_input)
        
        if self.is_input:
            err_check(
                lib.avformat_open_input(&self.proxy.ptr, name, NULL, NULL),
                name,
            )
            err_check(lib.avformat_find_stream_info(self.proxy.ptr, NULL))
            self.streams = list(stream_factory(self, i) for i in range(self.proxy.ptr.nb_streams))
            self.metadata = avdict_to_dict(self.proxy.ptr.metadata)
            
        if self.is_output:
            
            fmt = lib.av_guess_format(NULL, name, NULL)
            if not fmt:
                raise ValueError("Could not deduce output format")
            
            err_check(lib.avformat_alloc_output_context2(&self.proxy.ptr, fmt,NULL, name))
            self.streams = []
            self.metadata = {}
            
    cpdef add_stream(self, bytes codec_name, object rate=None):
        
        """Add stream to Container and return it.
        if the codec_name is a video codec rate means frames per second,
        if the codec_name is a audio codec rate means sample rate 
        Note: To use this Container must be opened with mode = "w"
        """
    
        if self.is_input:
            raise TypeError("Cannot add streams to input Container ")

        cdef lib.AVCodec *codec
        cdef lib.AVCodecDescriptor *desc
  
        cdef lib.AVStream *st
        cdef Stream stream
        
        # Find encoder
        codec = lib.avcodec_find_encoder_by_name(codec_name)
        
        if not codec:
            desc = lib.avcodec_descriptor_get_by_name(codec_name)
            if desc:
                codec = lib.avcodec_find_encoder(desc.id)
                
        if not codec:
            raise ValueError("Unknown encoder %s" % codec_name)
        
        # Check if format supports codec
        ret = lib.avformat_query_codec(self.proxy.ptr.oformat,
                                       codec.id,
                                       lib.FF_COMPLIANCE_NORMAL)
        if not ret:
            raise ValueError("Codec is not supported in this format")
        
        # Create new stream
        st = lib.avformat_new_stream(self.proxy.ptr, codec)
        if not st:
            raise MemoryError("Could not allocate stream")
        
        # Set Stream ID
        st.id = self.proxy.ptr.nb_streams -1
        codec_ctx = st.codec
        # Set Codecs defaults
        lib.avcodec_get_context_defaults3(codec_ctx, codec)
        
        stream = stream_factory(self,st.id)
        
        codec_ctx.codec = codec
        
        # Now lets set some more sane video defaults
        if stream._codec_context.codec_type == lib.AVMEDIA_TYPE_VIDEO:
            if not rate:
                rate = 25
            
            stream._codec_context.time_base.den = 12800 
            stream._codec_context.time_base.num = 1
            stream._codec_context.pix_fmt = lib.AV_PIX_FMT_YUV420P
            stream._codec_context.width = 640
            stream._codec_context.height = 480
            stream.codec.frame_rate = rate
        # Some Sane audio defaults
        elif codec_ctx.codec_type == lib.AVMEDIA_TYPE_AUDIO:
            if not rate:
                rate = 44100
            #choose codecs first available sample format
            stream._codec_context.sample_fmt = codec.sample_fmts[0]
            stream._codec_context.bit_rate = 64000
            stream._codec_context.sample_rate = int(rate)
            #codec_ctx.sample_rate = 48000

            stream._codec_context.channels = 2
            stream._codec_context.channel_layout = lib.AV_CH_LAYOUT_STEREO

        # Some formats want stream headers to be separate
        if self.proxy.ptr.oformat.flags & lib.AVFMT_GLOBALHEADER:
            stream._codec_context.flags |= lib.CODEC_FLAG_GLOBAL_HEADER
        
        # And steam object to self.streams
        
        self.streams.append(stream)
        return stream
    
    cpdef start_encoding(self):
    
        """setups Container for encoding. Opens Codecs and output file if they aren't already open 
        and writes file header. This method is automatically called by a Stream before encoding.
        Note: To use this Container must be opened with mode = "w"
        """
    
        if self.is_input:
            raise TypeError('Cannot encoded to input Container, file needs to be opened with mode="w"')

        cdef Stream stream
        
        for stream in self.streams:
            # Open Codec if its not open
            if not lib.avcodec_is_open(stream._codec_context):
                err_check(lib.avcodec_open2(stream._codec_context, stream._codec, NULL))

        filename = self.name
        
        # open the output file, if needed
        if not self.proxy.ptr.pb:
            
            if not self.proxy.ptr.oformat.flags & lib.AVFMT_NOFILE:
                err_check(lib.avio_open(&self.proxy.ptr.pb, filename, lib.AVIO_FLAG_WRITE))
    
            err_check(lib.avformat_write_header(self.proxy.ptr, NULL))
            
    def close(self):
        cdef Stream stream
        
        if self.is_output:
            if not self.proxy.ptr.pb:
                raise IOError("File not opened")
            
            err_check(lib.av_write_trailer(self.proxy.ptr))
            for stream in self.streams:
                
                lib.avcodec_close(stream._codec_context)
                
            if not self.proxy.ptr.oformat.flags & lib.AVFMT_NOFILE:
                lib.avio_closep(&self.proxy.ptr.pb)
        
    
    def dump(self):
        lib.av_dump_format(self.proxy.ptr, 0, self.name, self.mode == 'w')
        
    def mux(self, Packet packet):
        
        self.start_encoding()
        
        cdef int ret
        if self.is_input:
            raise ValueError("not a output file")
        #None and Null check
        if not packet:
            raise TypeError("argument must be a av.packet.Packet, not 'NoneType' or 'NULL'")
        
        err_check(lib.av_interleaved_write_frame(self.proxy.ptr, &packet.struct))
    
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
    
    property start_time:
        def __get__(self): return self.proxy.ptr.start_time
    property duration:
        def __get__(self): return self.proxy.ptr.duration
    property bit_rate:
        def __get__(self): return self.proxy.ptr.bit_rate
            
