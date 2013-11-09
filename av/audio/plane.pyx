cimport libav as lib

from av.audio.frame cimport AudioFrame


cdef class AudioPlane(Plane):
    
    def __cinit__(self, AudioFrame frame, int index):
        lib.av_samples_get_buffer_size(
            <int*>&self.buffer_size,
            frame.nb_channels,
            frame.ptr.nb_samples,
            <lib.AVSampleFormat>frame.ptr.format,
            frame.align
        )
