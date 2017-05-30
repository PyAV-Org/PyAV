from libc.stdint cimport int64_t, uint64_t

cimport libav as lib

from av.audio.frame cimport AudioFrame


cdef class AudioFifo:

    cdef lib.AVAudioFifo *ptr
    
    cdef AudioFrame template
    
    cdef int64_t last_pts
    cdef int64_t pts_offset
    
    cpdef write(self, AudioFrame frame)
    cpdef read(self, unsigned int samples=*, bint partial=*)
    