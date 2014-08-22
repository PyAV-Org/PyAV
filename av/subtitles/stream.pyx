cimport libav as lib

from av.frame cimport Frame
from av.subtitles.subtitle cimport SubtitleProxy, SubtitleSet
from av.packet cimport Packet
from av.utils cimport err_check


cdef class SubtitleStream(Stream):
    
    cdef _decode_one(self, lib.AVPacket *packet, int *data_consumed):
        
        cdef SubtitleProxy proxy = SubtitleProxy()
        
        cdef int completed_frame = 0
        data_consumed[0] = err_check(lib.avcodec_decode_subtitle2(self._codec_context, &proxy.struct, &completed_frame, packet))
        if not completed_frame:
            return
        
        return SubtitleSet(proxy)

