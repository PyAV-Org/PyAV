cimport libav as lib

from av.subtitles.subtitle cimport SubtitleProxy, Subtitle
from av.packet cimport Packet
from av.utils cimport err_check


cdef class SubtitleStream(Stream):
    
    cpdef decode(self, Packet packet):
        
        cdef SubtitleProxy proxy = SubtitleProxy()
        
        cdef int done = 0
        err_check(lib.avcodec_decode_subtitle2(self.codec.ctx, &proxy.struct, &done, &packet.struct))
        if not done:
            return
        
        return Subtitle(packet, proxy)

