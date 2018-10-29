from av.video.frame cimport VideoFrame


cdef class VideoPlane(Plane):

    def __cinit__(self, VideoFrame frame, int index):

        for i in range(frame.format.ptr.nb_components):
            if frame.format.ptr.comp[i].plane == index:
                self.component = frame.format.components[i]
                break
        else:
            raise RuntimeError('could not find plane %d of %r' % (index, frame.format))

        # Sometimes, linesize is negative (and that is meaningful). We are only
        # insisting that the buffer size be based on the extent of linesize, and
        # ignore it's direction.
        self.buffer_size = abs(self.frame.ptr.linesize[self.index]) * self.component.height

    cdef size_t _buffer_size(self):
        return self.buffer_size

    property line_size:
        """
        Bytes per horizontal line in this plane.

        :type: int
        """
        def __get__(self):
            return self.frame.ptr.linesize[self.index]

    property width:
        """Pixel width of this plane."""
        def __get__(self):
            return self.component.width

    property height:
        """Pixel height of this plane."""
        def __get__(self):
            return self.component.height
