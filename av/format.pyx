"""Autodoc module test."""

from libc.stdint cimport uint8_t
from libc.stdlib cimport malloc, free

cimport libav as lib

from .utils cimport err_check, avdict_to_dict, avrational_to_faction
from .utils import Error, LibError

cimport av.codec


time_base = lib.AV_TIME_BASE


cdef class ContextProxy(object):

    def __init__(self, bint is_input):
        self.is_input = is_input
    
    def __dealloc__(self):
        if self.ptr != NULL:
            if self.is_input:
                lib.avformat_close_input(&self.ptr)


cdef class Context(object):

    """Autodoc class test."""

    def __init__(self, name, mode='r'):
        
        cdef lib.AVOutputFormat* fmt
        
        if mode == 'r':
            self.is_input = True
            self.is_output = False
        elif mode == 'w':
            self.is_input = False
            self.is_output = True
            #raise NotImplementedError('no output yet')
        else:
            raise ValueError('mode must be "r" or "w"')
        
        self.name = name
        self.mode = mode
        
        self.proxy = ContextProxy(self.is_input)
        
        if self.is_input:
            err_check(lib.avformat_open_input(&self.proxy.ptr, name, NULL, NULL))
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
            
    cpdef add_stream(self, char* codec_name):

        cdef lib.AVCodec *codec
        cdef lib.AVCodecContext *codec_ctx
        cdef lib.AVCodecDescriptor *desc
  
        cdef lib.AVStream *stream
        
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
        stream = lib.avformat_new_stream(self.proxy.ptr, codec)
        if not stream:
            raise MemoryError("Could not allocate stream")
        
        # Set Stream ID
        stream.id = self.proxy.ptr.nb_streams -1
        codec_ctx = stream.codec
        # Set Codecs defaults
        lib.avcodec_get_context_defaults3(codec_ctx, codec)
        
        codec_ctx.codec = codec
        
        # Now lets set some more sane video defaults
        if codec_ctx.codec_type == lib.AVMEDIA_TYPE_VIDEO:
            codec_ctx.time_base.den = 25
            codec_ctx.time_base.num = 1
            codec_ctx.pix_fmt = lib.AV_PIX_FMT_YUV420P
            codec_ctx.width = 640
            codec_ctx.height = 480
        
        # Some Sane audio defaults
        elif codec_ctx.codec_type == lib.AVMEDIA_TYPE_AUDIO:
            #choose codecs first availbe sample format
            codec_ctx.sample_fmt = codec.sample_fmts[0]
            codec_ctx.bit_rate = 64000
            codec_ctx.sample_rate = 44100
            #codec_ctx.sample_rate = 48000

            codec_ctx.channels = 2
            codec_ctx.channel_layout = lib.AV_CH_LAYOUT_STEREO

        # Some formats want stream headers to be separate
        if self.proxy.ptr.oformat.flags & lib.AVFMT_GLOBALHEADER:
            codec_ctx.flags |= lib.CODEC_FLAG_GLOBAL_HEADER
        
        # And steam object to self.streams
        stream_obj = stream_factory(self,stream.id)
        self.streams.append(stream_obj)
        
        return stream_obj
    
    cpdef begin_encoding(self):
        print "encoding starting"
        
        cdef Stream stream
        
        for stream in self.streams:
            # Open Codec if its not open
            if not lib.avcodec_is_open(stream.codec.ctx):
                ret = lib.avcodec_open2(stream.codec.ctx, stream.codec.ptr, NULL)
                if ret <0:
                    raise Exception("Could not open video codec: %s" % lib.av_err2str(ret))
                print "opened codec for", stream
                
        filename = self.name
        
        # open the output file, if needed
        if not self.proxy.ptr.oformat.flags & lib.AVFMT_NOFILE:
            ret = lib.avio_open(&self.proxy.ptr.pb, filename, lib.AVIO_FLAG_WRITE)
            if ret <0:
                raise Exception("Could not open '%s' %s" % (filename,lib.av_err2str(ret)))

        ret = lib.avformat_write_header(self.proxy.ptr, NULL)
        if ret < 0:
            raise Exception("Error occurred when opening output file: %s" %  lib.av_err2str(ret))
        
    def close(self):
        cdef Stream stream
        
        if self.is_output:
            lib.av_write_trailer(self.proxy.ptr)
            
            for stream in self.streams:
                stream.flush_encoder()
                
            for stream in self.streams:
                
                lib.avcodec_close(stream.codec.ctx)
                
            if not self.proxy.ptr.oformat.flags & lib.AVFMT_NOFILE:
                lib.avio_close(self.proxy.ptr.pb)
        
    
    def dump(self):
        lib.av_dump_format(self.proxy.ptr, 0, self.name, self.mode == 'w')
        
    def mux(self, av.codec.Packet packet):
        cdef int ret
        if self.is_input:
            raise ValueError("not a output file")
        #None and Null check
        if not packet:
            raise TypeError("argument must be a av.codec.Packet, not 'NoneType' or 'NULL'")
        
        err_check(lib.av_interleaved_write_frame(self.proxy.ptr, &packet.struct))
    
    def demux(self, streams=None):
        
        cdef bint *include_stream = <bint*>malloc(self.proxy.ptr.nb_streams * sizeof(bint))
        if include_stream == NULL:
            raise MemoryError()
        
        cdef int i
        cdef av.codec.Packet packet

        try:
            
            for i in range(self.proxy.ptr.nb_streams):
                include_stream[i] = False
            for stream in streams or self.streams:
                include_stream[stream.index] = True
        
            while True:
                packet = av.codec.Packet()
                try:
                    err_check(lib.av_read_frame(self.proxy.ptr, &packet.struct))
                except LibError:
                    break
                    
                if include_stream[packet.struct.stream_index]:
                    # If AVFMTCTX_NOHEADER is set in ctx_flags, then new streams 
                    # may also appear in av_read_frame().
                    # http://ffmpeg.org/doxygen/trunk/structAVFormatContext.html
                    # TODO: find better way to handle this 
                    if packet.struct.stream_index < len(self.streams):
                        packet.stream = self.streams[packet.struct.stream_index]
                        yield packet


            # Some codecs will cause frames to be buffered up in the decoding process.
            # These codecs should have a CODEC CAP_DELAY capability set.
            # This sends a special packet with data set to NULL and size set to 0
            # This tells the Packet Object that its the last packet
            
            for i in range(self.proxy.ptr.nb_streams):

                if include_stream[i]:
                    packet = av.codec.Packet()
                    packet.struct.data= NULL
                    packet.struct.size = 0
                    packet.is_null = True
                    stream = self.streams[i]
                    packet.stream = stream
                    
                    yield packet
        finally:
            free(include_stream)
    
    property start_time:
        def __get__(self): return self.proxy.ptr.start_time
    property duration:
        def __get__(self): return self.proxy.ptr.duration
    property bit_rate:
        def __get__(self): return self.proxy.ptr.bit_rate
            


cdef Stream stream_factory(Context ctx, int index):
    
    cdef lib.AVStream *ptr = ctx.proxy.ptr.streams[index]
    
    if ptr.codec.codec_type == lib.AVMEDIA_TYPE_VIDEO:
        return VideoStream(ctx, index, 'video')
    elif ptr.codec.codec_type == lib.AVMEDIA_TYPE_AUDIO:
        return AudioStream(ctx, index, 'audio')
    elif ptr.codec.codec_type == lib.AVMEDIA_TYPE_DATA:
        return DataStream(ctx, index, 'data')
    elif ptr.codec.codec_type == lib.AVMEDIA_TYPE_SUBTITLE:
        return SubtitleStream(ctx, index, 'subtitle')
    elif ptr.codec.codec_type == lib.AVMEDIA_TYPE_ATTACHMENT:
        return AttachmentStream(ctx, index, 'attachment')
    elif ptr.codec.codec_type == lib.AVMEDIA_TYPE_NB:
        return NBStream(ctx, index, 'nb')
    else:
        return Stream(ctx, index)


cdef class Stream(object):
    
    def __init__(self, Context ctx, int index, bytes type=b'unknown'):
        
        if index < 0 or index > ctx.proxy.ptr.nb_streams:
            raise ValueError('stream index out of range')
        
        self.ctx_proxy = ctx.proxy
        self.ptr = self.ctx_proxy.ptr.streams[index]
        self.type = type

        self.codec = av.codec.Codec(self)
        self.metadata = avdict_to_dict(self.ptr.metadata)
    
    def __repr__(self):
        return '<%s.%s #%d %s/%s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.index,
            self.type,
            self.codec.name,
            id(self),
        )
    
    property index:
        def __get__(self): return self.ptr.index
    property id:
        def __get__(self): return self.ptr.id
    property time_base:
        def __get__(self): return avrational_to_faction(&self.ptr.time_base)
    property base_frame_rate:
        def __get__(self): return avrational_to_faction(&self.ptr.r_frame_rate)
    property avg_frame_rate:
        def __get__(self): return avrational_to_faction(&self.ptr.avg_frame_rate)
    property start_time:
        def __get__(self): return self.ptr.start_time
    property duration:
        def __get__(self): return self.ptr.duration
    property frames:
        def __get__(self): return self.ptr.nb_frames
    
    cpdef decode(self, av.codec.Packet packet):
        return None

cdef class VideoStream(Stream):
    
    def __init__(self, *args):
        super(VideoStream, self).__init__(*args)
        self.last_w = 0
        self.last_h = 0
        
        self.encoded_frame_count = 0
    
    def __dealloc__(self):
        # These are all NULL safe.
        lib.avcodec_free_frame(&self.raw_frame)
        
    cpdef decode(self, av.codec.Packet packet):
        
        if not self.raw_frame:
            self.raw_frame = lib.avcodec_alloc_frame()
            lib.avcodec_get_frame_defaults(self.raw_frame)

        cdef int done = 0
        err_check(lib.avcodec_decode_video2(self.codec.ctx, self.raw_frame, &done, &packet.struct))
        if not done:
            return
        
        # Check if the frame size has change
        if not (self.last_w,self.last_h) == (self.codec.ctx.width,self.codec.ctx.height):
            
            self.last_w = self.codec.ctx.width
            self.last_h = self.codec.ctx.height
            
            # Recalculate buffer size
            self.buffer_size = lib.avpicture_get_size(
                self.codec.ctx.pix_fmt,
                self.codec.ctx.width,
                self.codec.ctx.height,
            )
            
            # Create a new SwsContextProxy
            self.sws_proxy = av.codec.SwsContextProxy()

        cdef av.codec.VideoFrame frame = av.codec.VideoFrame()
        
        # Copy the pointers over.
        frame.buffer_size = self.buffer_size
        frame.ptr = self.raw_frame

        # Calculate best effort time stamp    
        frame.ptr.pts = lib.av_frame_get_best_effort_timestamp(frame.ptr)
        
        # Copy SwsContextProxy so frames share the same one
        frame.sws_proxy = self.sws_proxy
        
        # Null out our frame.
        self.raw_frame = NULL
        
        return frame
    
    cpdef encode(self, av.codec.VideoFrame frame):

        if not self.sws_proxy:
            self.sws_proxy =  av.codec.SwsContextProxy() 
        frame.sws_proxy = self.sws_proxy

        cdef av.codec.VideoFrame formated_frame
        
        formated_frame = frame.reformat(self.codec.width,self.codec.height, self.codec.pix_fmt)
        formated_frame.ptr.pts = self.encoded_frame_count
        
        self.encoded_frame_count += 1
        
        cdef av.codec.Packet packet = av.codec.Packet()
        cdef int got_output
        
        packet.struct.data = NULL #packet data will be allocated by the encoder
        packet.struct.size = 0
        
        ret = lib.avcodec_encode_video2(self.codec.ctx, &packet.struct, formated_frame.ptr, &got_output)
        if ret <0:
            raise Exception("Error encoding video frame: %s" % lib.av_err2str(ret))
        
        if got_output:

            if packet.struct.pts != lib.AV_NOPTS_VALUE:
                packet.struct.pts = lib.av_rescale_q(packet.struct.pts, 
                                                         self.codec.ctx.time_base,
                                                         self.ptr.time_base)
            if packet.struct.dts != lib.AV_NOPTS_VALUE:
                packet.struct.dts = lib.av_rescale_q(packet.struct.dts, 
                                                     self.codec.ctx.time_base,
                                                     self.ptr.time_base)
            if self.codec.ctx.coded_frame.key_frame:
                packet.struct.flags |= lib.AV_PKT_FLAG_KEY
                
            packet.struct.stream_index = self.ptr.index
            #ret = lib.av_interleaved_write_frame(self.ctx_proxy.ptr, &packet.struct)
            return packet
        
    cpdef flush_encoder(self):
        pass

        

cdef class AudioStream(Stream):

    def __init__(self, *args):
        super(AudioStream, self).__init__(*args)
        self.encoded_frame_count = 0
    
    property sample_rate:
        def __get__(self):
            return self.codec.ctx.sample_rate

    property channels:
        def __get__(self):
            return self.codec.ctx.channels

    def __dealloc__(self):
        # These are all NULL safe.
        lib.av_free(self.frame)
        
    cpdef decode(self, av.codec.Packet packet):
        if not self.frame:
            self.frame = lib.avcodec_alloc_frame()

        cdef int done = 0
        err_check(lib.avcodec_decode_audio4(self.codec.ctx, self.frame, &done, &packet.struct))
        if not done:
            return
        
        if not self.swr_proxy:
            self.swr_proxy =  av.codec.SwrContextProxy() 

        cdef av.codec.AudioFrame frame = av.codec.AudioFrame()
        
        # Copy the pointers over.
        frame.ptr = self.frame
        frame.swr_proxy = self.swr_proxy
        
        frame.ptr.pts = lib.av_frame_get_best_effort_timestamp(frame.ptr)
        
        # Null out ours.
        self.frame = NULL
        
        return frame
    
    cpdef encode(self, av.codec.AudioFrame frame):
    
        if not self.swr_proxy:
            self.swr_proxy =  av.codec.SwrContextProxy()
        
        # setup audio fifo
        if not self.fifo:
            self.fifo = av.codec.AudioFifo(self.codec.channel_layout,
                                           self.codec.sample_fmt,
                                           self.codec.sample_rate,
                                           self.codec.frame_size)
            self.fifo.add_silence = True
            
        cdef av.codec.Packet packet
        cdef av.codec.AudioFrame fifo_frame
        cdef int got_output
            
        flush = False
        
        if not frame:
            flush = True
        else:
            frame.swr_proxy = self.swr_proxy
            self.fifo.write(frame)

        for fifo_frame in self.fifo.get_frames(self.codec.frame_size,flush):
            packet = av.codec.Packet()
            packet.struct.data = NULL #packet data will be allocated by the encoder
            packet.struct.size = 0
            
            
            if fifo_frame:
                fifo_frame.ptr.pts = self.encoded_frame_count
                self.encoded_frame_count += fifo_frame.samples
                ret = lib.avcodec_encode_audio2(self.codec.ctx, &packet.struct, fifo_frame.ptr, &got_output)
            else:
                ret = lib.avcodec_encode_audio2(self.codec.ctx, &packet.struct, NULL, &got_output)

            if ret < 0:
                raise Exception("Error encoding audio frame: %s" % lib.av_err2str(ret))
            
            if got_output:
            
                if packet.struct.pts != lib.AV_NOPTS_VALUE:
                    packet.struct.pts = lib.av_rescale_q(packet.struct.pts, 
                                                         self.codec.ctx.time_base,
                                                         self.ptr.time_base)
                if packet.struct.dts != lib.AV_NOPTS_VALUE:
                    packet.struct.dts = lib.av_rescale_q(packet.struct.dts, 
                                                         self.codec.ctx.time_base,
                                                         self.ptr.time_base)

                if packet.struct.duration > 0:
                    packet.struct.duration = lib.av_rescale_q(packet.struct.duration, 
                                                         self.codec.ctx.time_base,
                                                         self.ptr.time_base)
                    
                if self.codec.ctx.coded_frame.key_frame:
                    packet.struct.flags |= lib.AV_PKT_FLAG_KEY
    
                packet.struct.stream_index = self.ptr.index
                packet.stream = self
                
                return packet
                #ret = lib.av_interleaved_write_frame(self.ctx_proxy.ptr, &packet.struct)

    cpdef flush_encoder(self):
        pass


cdef class SubtitleStream(Stream):
    
    cpdef decode(self, av.codec.Packet packet):
        
        cdef av.codec.SubtitleProxy proxy = av.codec.SubtitleProxy()
        cdef av.codec.Subtitle sub = None
        
        cdef int done = 0
        err_check(lib.avcodec_decode_subtitle2(self.codec.ctx, &proxy.struct, &done, &packet.struct))
        if not done:
            return
        
        return av.codec.Subtitle(packet, proxy)
        

cdef class DataStream(Stream):
    pass

cdef class AttachmentStream(Stream):
    pass

cdef class NBStream(Stream):
    pass


# Handy alias.
open = Context
