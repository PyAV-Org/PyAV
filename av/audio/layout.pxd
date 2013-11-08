from libc.stdint cimport uint64_t


cdef class AudioLayout(object):

    # The layout for FFMpeg; this is essentially a bitmask of channels.
    cdef uint64_t layout
    cdef int nb_channels
    
    cdef readonly tuple channels

    cdef _init(self, uint64_t layout)


cdef class AudioChannel(object):

    cdef AudioLayout layout
    cdef int index

    # The channel for FFmpeg.
    cdef uint64_t channel
