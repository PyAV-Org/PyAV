from libc.stdint cimport uint8_t, int64_t
from cpython cimport PyWeakref_NewRef

cimport libav as lib

from av.audio.stream cimport AudioStream
from av.codec cimport codec_factory
from av.packet cimport Packet
from av.subtitles.stream cimport SubtitleStream
from av.utils cimport err_check, avdict_to_dict, avrational_to_faction
from av.video.stream cimport VideoStream


cdef Stream stream_factory(Container ctx, int index):
    
    cdef lib.AVStream *ptr = ctx.proxy.ptr.streams[index]
    
    if ptr.codec.codec_type == lib.AVMEDIA_TYPE_VIDEO:
        return VideoStream(ctx, index, 'video')
    elif ptr.codec.codec_type == lib.AVMEDIA_TYPE_AUDIO:
        return AudioStream(ctx, index, 'audio')
    elif ptr.codec.codec_type == lib.AVMEDIA_TYPE_DATA:
        return Stream(ctx, index, 'data')
    elif ptr.codec.codec_type == lib.AVMEDIA_TYPE_SUBTITLE:
        return Stream(ctx, index, 'subtitle')
    elif ptr.codec.codec_type == lib.AVMEDIA_TYPE_ATTACHMENT:
        return Stream(ctx, index, 'attachment')
    elif ptr.codec.codec_type == lib.AVMEDIA_TYPE_NB:
        return Stream(ctx, index, 'nb')
    else:
        return Stream(ctx, index)


cdef class Stream(object):
    
    def __cinit__(self, Container ctx, int index, bytes type=b'unknown'):
        
        if index < 0 or index > ctx.proxy.ptr.nb_streams:
            raise ValueError('stream index out of range')
        
        self.ctx = ctx.proxy
        self.weak_ctx = PyWeakref_NewRef(ctx, None)

        self.ptr = self.ctx.ptr.streams[index]
        self.type = type

        self.codec = codec_factory(self)
        self.metadata = avdict_to_dict(self.ptr.metadata)
    
    def __repr__(self):
        return '<av.%s #%d %s/%s at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.type or '<notype>',
            self.codec.name or '<nocodec>',
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

        cdef Frame frame
        cdef unsigned int frames_decoded = 0
        cdef int data_consumed = 0
        cdef list frames = []

        cdef uint8_t *original_data = packet.struct.data
        cdef int      original_size = packet.struct.size

        while packet.struct.size > 0:

            frame = self._decode_one(&packet.struct, &data_consumed)
            if not data_consumed:
                raise RuntimeError('no data consumed from packet')
            if packet.struct.data:
                packet.struct.data += data_consumed
            packet.struct.size -= data_consumed

            if frame:
                frames_decoded += 1
                self._setup_frame(frame)
                frames.append(frame)

        # Restore the packet.
        packet.struct.data = original_data
        packet.struct.size = original_size

        # Some codecs will cause frames to be buffered up in the decoding process.
        # These codecs should have a CODEC CAP_DELAY capability set.
        # This sends a special packet with data set to NULL and size set to 0
        # This tells the Packet Object that its the last packet    
        if frames_decoded:
            while True:
                # Create a new NULL packet for every frame we try to pull out.
                packet = Packet()
                frame = self._decode_one(&packet.struct, &data_consumed)
                if frame:
                    self._setup_frame(frame)
                    frames.append(frame)
                else:
                    break

        return frames
    
    cdef _setup_frame(self, Frame frame):
        frame.ptr.pts = lib.av_frame_get_best_effort_timestamp(frame.ptr)
        frame.time_base = self.ptr.time_base

    cdef Frame _decode_one(self, lib.AVPacket *packet, int *data_consumed):
        raise NotImplementedError('base stream cannot decode packets')

