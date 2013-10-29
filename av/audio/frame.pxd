from libc.stdint cimport uint8_t, uint64_t, int64_t

cimport libav as lib

from av.frame cimport Frame
from av.audio.swrcontext cimport SwrContextProxy


cdef class AudioFrame(Frame):

    cdef int buffer_size
    cdef int align
    cdef uint8_t **buffer_
    cdef readonly int frame_index
    
    cdef alloc_frame(self, int channels, lib.AVSampleFormat sample_fmt, int nb_samples)
    cdef fill_frame(self, int nb_samples)
    cdef SwrContextProxy swr_proxy
    cpdef resample(self, bytes channel_layout, bytes sample_fmt, int sample_rate)
    

cdef class AudioFifo:

    cdef lib.AVAudioFifo *ptr
    
    cdef uint64_t channel_layout_
    cdef int channels_
    cdef bint add_silence
    
    cdef lib.AVSampleFormat sample_fmt_
    cdef int sample_rate_
    
    cdef int64_t last_pts
    cdef int64_t pts_offset
    cdef lib.AVRational time_base_
    
    cpdef write(self, AudioFrame frame)
    cpdef read(self, int nb_samples=*)
    
