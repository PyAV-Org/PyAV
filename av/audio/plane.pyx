from av.audio.frame cimport AudioFrame


cdef class AudioPlane(Plane):

    def __cinit__(self, AudioFrame frame, int index):
        # Only the first linesize is ever populated, but it applies to every plane.
        self.buffer_size = self.frame.ptr.linesize[0]

    cdef size_t _buffer_size(self):
        return self.buffer_size
