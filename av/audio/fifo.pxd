from libc.stdint cimport int64_t, uint64_t

cimport libav as lib

from av.audio.layout cimport AudioLayout
from av.audio.format cimport AudioFormat
from av.audio.frame cimport AudioFrame


cdef class AudioFifo:

    cdef lib.AVAudioFifo *ptr
    
    cdef readonly AudioFormat format
    cdef readonly AudioLayout layout
        
    cdef int64_t last_pts
    cdef int64_t pts_offset
    cdef lib.AVRational time_base
    
    cpdef write(self, AudioFrame frame)
    cpdef read(self, unsigned int nb_samples=*, bint partial=*)
    
