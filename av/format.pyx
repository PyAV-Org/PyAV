"""Autodoc module test."""

from libc.stdint cimport uint8_t
from libc.stdlib cimport malloc, free

cimport libav as lib

from .utils cimport err_check, avdict_to_dict, avrational_to_faction
from .utils import Error, LibError

cimport av.codec


time_base = lib.AV_TIME_BASE


cdef lib.uint64_t global_video_pkt_pts = lib.AV_NOPTS_VALUE

cdef int pyav_get_buffer(lib.AVCodecContext *ctx, lib.AVFrame *frame):
    #print 'get buffer',global_video_pkt_pts
    cdef int ret
    ret = lib.avcodec_default_get_buffer(ctx, frame)
    cdef lib.uint64_t *pts = <lib.uint64_t*>lib.av_malloc(sizeof(lib.uint64_t))
    
    pts[0] = global_video_pkt_pts
    frame.opaque = pts
    
    return ret

cdef void pyav_release_buffer(lib.AVCodecContext *ctx, lib.AVFrame *frame):
    #print 'release buffer'
    
    if frame:
        lib.av_freep(&frame.opaque)
    
    lib.avcodec_default_release_buffer(ctx, frame)

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
        
        if mode == 'r':
            self.is_input = True
            self.is_output = False
        elif mode == 'w':
            self.is_input = False
            self.is_output = True
            raise NotImplementedError('no output yet')
        else:
            raise ValueError('mode must be "r" or "w"')
        
        self.name = name
        self.mode = mode
        self.proxy = ContextProxy(self.is_input)
        
        if self.is_input:
            err_check(lib.avformat_open_input(&self.proxy.ptr, name, NULL, NULL))
            err_check(lib.avformat_find_stream_info(self.proxy.ptr, NULL))
        
        self.streams = tuple(stream_factory(self, i) for i in range(self.proxy.ptr.nb_streams))
        self.metadata = avdict_to_dict(self.proxy.ptr.metadata)
    
    def dump(self):
        lib.av_dump_format(self.proxy.ptr, 0, self.name, self.mode == 'w')
    
    def demux(self, streams=None):
        
        cdef bint *include_stream = <bint*>malloc(self.proxy.ptr.nb_streams * sizeof(bint))
        if include_stream == NULL:
            raise MemoryError()
        
        cdef int i
        cdef av.codec.Packet packet
        cdef av.format.Stream stream

        try:
            
            for i in range(self.proxy.ptr.nb_streams):
                include_stream[i] = False
            for stream in streams or self.streams:
                stream.flush_buffers()
                include_stream[stream.index] = True
        
            while True:
                packet = av.codec.Packet()
                try:
                    err_check(lib.av_read_frame(self.proxy.ptr, &packet.struct))
                except LibError:
                    break
                    
                if include_stream[packet.struct.stream_index]:
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
        self.ctx = ctx
        self.ptr = self.ctx_proxy.ptr.streams[index]
        self.type = type

        self.codec = av.codec.Codec(self)
        self.metadata = avdict_to_dict(self.ptr.metadata)
        
        self.codec.ctx.get_buffer = pyav_get_buffer
        self.codec.ctx.release_buffer = pyav_release_buffer

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
    
    def __dealloc__(self):
        # These are all NULL safe.
        lib.av_free(self.raw_frame)
        lib.av_free(self.rgb_frame)
        lib.av_free(self.buffer_)
        lib.sws_freeContext(self.sws_ctx)
        
    cpdef decode(self, av.codec.Packet packet):
        
        if not self.raw_frame:
            self.raw_frame = lib.avcodec_alloc_frame()
            self.rgb_frame = lib.avcodec_alloc_frame()

        cdef int done = 0
        
        global global_video_pkt_pts
        
        global_video_pkt_pts = packet.struct.pts
        #print "global pts", packet.struct.pts
        
        err_check(lib.avcodec_decode_video2(self.codec.ctx, self.raw_frame, &done, &packet.struct))
        if not done:
            return
        
        cdef lib.uint64_t *opaque_pts
        cdef lib.uint64_t pts = 0
        
        opaque_pts = <lib.uint64_t*>self.raw_frame.opaque
        
        
        if packet.struct.dts == lib.AV_NOPTS_VALUE and \
                                        opaque_pts and \
                                        opaque_pts[0] != lib.AV_NOPTS_VALUE:
            pts = opaque_pts[0]
        
        elif packet.struct.dts != lib.AV_NOPTS_VALUE:
            pts = packet.struct.dts
        
        print lib.av_q2d(self.ptr.time_base)
        #pts *= <lib.uint64_t>lib.av_q2d(self.ptr.time_base)
        #print "best pts =", pts
        
        # Check if the frame size has change
        if not (self.last_w,self.last_h) == (self.codec.ctx.width,self.codec.ctx.height):
            
            self.last_w = self.codec.ctx.width
            self.last_h = self.codec.ctx.height

            self.buffer_size = lib.avpicture_get_size(
                lib.PIX_FMT_RGBA,
                self.codec.ctx.width,
                self.codec.ctx.height,
            )
            
            if self.sws_ctx:
                lib.sws_freeContext(self.sws_ctx)
            
            self.sws_ctx = lib.sws_getContext(
                self.codec.ctx.width,
                self.codec.ctx.height,
                self.codec.ctx.pix_fmt,
                self.codec.ctx.width,
                self.codec.ctx.height,
                lib.PIX_FMT_RGBA,
                lib.SWS_BILINEAR,
                NULL,
                NULL,
                NULL
            )
            
            
            
        self.buffer_ = <uint8_t *>lib.av_malloc(self.buffer_size * sizeof(uint8_t))
        
        # Assign the buffer to the image planes.
        lib.avpicture_fill(
                <lib.AVPicture *>self.rgb_frame,
                self.buffer_,
                lib.PIX_FMT_RGBA,
                self.codec.ctx.width,
                self.codec.ctx.height
            )

        # Scale and convert.
        lib.sws_scale(
            self.sws_ctx,
            self.raw_frame.data,
            self.raw_frame.linesize,
            0, # slice Y
            self.codec.ctx.height,
            self.rgb_frame.data,
            self.rgb_frame.linesize,
        )
        
        cdef av.codec.VideoFrame frame = av.codec.VideoFrame(packet)
        
        # Copy the pointers over.
        frame.buffer_ = self.buffer_
        frame.raw_ptr = self.raw_frame
        frame.rgb_ptr = self.rgb_frame
        frame.pts_ = pts
        
        # Null out ours.
        self.buffer_ = NULL
        self.raw_frame = NULL
        self.rgb_frame = NULL
        
        return frame


cdef class AudioStream(Stream):
    
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
        
        cdef av.codec.AudioFrame frame = av.codec.AudioFrame(packet)
        
        # Copy the pointers over.
        frame.ptr = self.frame
        
        # Null out ours.
        self.frame = NULL
        
        return frame



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
