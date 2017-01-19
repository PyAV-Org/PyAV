cimport libav as lib

from codec cimport CodecContext

from av.video.frame cimport VideoFrame
from av.audio.frame cimport AudioFrame
from av.audio.fifo cimport AudioFifo

cdef class Encoder(CodecContext):
    cdef AudioFifo fifo
    cdef encode_video_frame(self, VideoFrame frame=*)
    cdef encode_audio_frame(self, AudioFrame frame=*)
