from libc.stdint cimport uint8_t, int64_t
from cpython cimport PyWeakref_NewRef

cimport libav as lib

from av.audio.stream cimport AudioStream
from av.codec cimport Codec
from av.packet cimport Packet
from av.subtitles.stream cimport SubtitleStream
from av.utils cimport err_check, avdict_to_dict, avrational_to_faction
from av.video.stream cimport VideoStream


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
        
        self.ctx = ctx.proxy
        self.weak_ctx = PyWeakref_NewRef(ctx, None)

        self.ptr = self.ctx.ptr.streams[index]
        self.type = type

        self.codec = Codec(self)
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
    
    cpdef decode(self, Packet packet):
        return None


cdef class AttachmentStream(Stream):
    pass
cdef class DataStream(Stream):
    pass
cdef class NBStream(Stream):
    pass

