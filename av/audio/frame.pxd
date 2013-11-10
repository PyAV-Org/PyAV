from libc.stdint cimport uint8_t, uint64_t

cimport libav as lib

from av.frame cimport Frame
from av.audio.format cimport AudioFormat
from av.audio.layout cimport AudioLayout


cdef class AudioFrame(Frame):

    # For raw storage of the frame's data; don't ever touch this.
    cdef uint8_t *_buffer

    cdef bint align
    cdef int nb_channels
    cdef int nb_planes

    cdef readonly int frame_index
    

    cdef readonly AudioLayout layout
    cdef readonly AudioFormat format
    
    cdef _init(self, lib.AVSampleFormat format, uint64_t layout, unsigned int nb_samples, bint align)
    cdef _init_properties(self)

cdef AudioFrame alloc_audio_frame()
