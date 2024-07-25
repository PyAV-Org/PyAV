cimport libav as lib


cdef class AudioLayout:
    cdef lib.AVChannelLayout layout
    cdef _init(self, lib.AVChannelLayout layout)

cdef AudioLayout get_audio_layout(int channels, lib.AVChannelLayout c_layout)
