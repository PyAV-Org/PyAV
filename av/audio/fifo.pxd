from libc.stdint cimport int64_t, uint64_t

cimport libav as lib

from av.audio.frame cimport AudioFrame


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
    
