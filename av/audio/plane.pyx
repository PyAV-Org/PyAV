cimport libav as lib

from av.audio.frame cimport AudioFrame


cdef class AudioPlane(Plane):
    
    def __cinit__(self, AudioFrame frame, int index):

        # We have to calculate this manually, since the provided linesize
        # array of the AVFrame only sets the first element, and does not
        # even seem to calculate it properly.
        lib.av_samples_get_buffer_size(
            <int*>&self.buffer_size,
            frame.nb_channels,
            frame.ptr.nb_samples,
            <lib.AVSampleFormat>frame.ptr.format,
            frame.align
        )

    cdef size_t _buffer_size(self):
        return self.buffer_size
