from av.video.frame cimport VideoFrame


cdef class VideoPlane(Plane):
    def __cinit__(self, VideoFrame frame, int index):
        # The palette plane has no associated component or linesize; set fields manually
        if frame.format.name == "pal8" and index == 1:
            self.width = 256
            self.height = 1
            self.buffer_size = 256 * 4
            return

        for i in range(frame.format.ptr.nb_components):
            if frame.format.ptr.comp[i].plane == index:
                component = frame.format.components[i]
                self.width = component.width
                self.height = component.height
                break
        else:
            raise RuntimeError(f"could not find plane {index} of {frame.format!r}")

        # Sometimes, linesize is negative (and that is meaningful). We are only
        # insisting that the buffer size be based on the extent of linesize, and
        # ignore it's direction.
        self.buffer_size = abs(self.frame.ptr.linesize[self.index]) * self.height

    cdef size_t _buffer_size(self):
        return self.buffer_size

    @property
    def line_size(self):
        """
        Bytes per horizontal line in this plane.

        :type: int
        """
        return self.frame.ptr.linesize[self.index]
