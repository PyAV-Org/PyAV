cimport libav as lib

from av.frame cimport Frame
from av.subtitles.subtitle cimport SubtitleProxy, SubtitleSet
from av.utils cimport err_check


cdef class SubtitleCodecContext(CodecContext):

    cdef _decode(self, lib.AVPacket *packet, int *data_consumed):

        cdef SubtitleProxy proxy = SubtitleProxy()

        cdef int got_frame = 0
        data_consumed[0] = err_check(lib.avcodec_decode_subtitle2(self.ptr, &proxy.struct, &got_frame, packet))
        if got_frame:
            return SubtitleSet(proxy)
