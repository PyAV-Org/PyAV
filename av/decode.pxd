cimport libav as lib

from codec cimport CodecContext

from av.packet cimport Packet
from av.frame cimport Frame

cdef class Decoder(CodecContext):
    cdef Frame next_frame
    cdef decode_one(self, Packet packet, int *data_consumed)
    cdef decode_video_frame(self, Packet packet, int *data_consumed)
    cdef decode_audio_frame(self, Packet packet, int *data_consumed)
    cdef decode_subtitle_frame(self, Packet packet, int *data_consumed)
