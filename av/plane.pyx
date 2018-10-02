from av.deprecation import renamed_attr


cdef class Plane(Buffer):
    """
    Base class for audio and video planes.

    See also :class:`~av.audio.plane.AudioPlane` and :class:`~av.video.plane.VideoPlane`.
    """

    def __cinit__(self, Frame frame, int index):
        self.frame = frame
        self.index = index

    def __repr__(self):
        return '<av.%s at 0x%x>' % (self.__class__.__name__, id(self))

    property line_size:
        """
        Bytes per horizontal line in this plane.

        :type: int
        """
        def __get__(self):
            return self.frame.ptr.linesize[self.index]

    ptr = renamed_attr('buffer_ptr')

    cdef size_t _buffer_size(self):
        return self.frame.ptr.linesize[self.index]

    cdef void*  _buffer_ptr(self):
        return self.frame.ptr.extended_data[self.index]

    update_from_string = renamed_attr('update')
