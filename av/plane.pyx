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

    ptr = renamed_attr('buffer_ptr')

    cdef void*  _buffer_ptr(self):
        return self.frame.ptr.extended_data[self.index]

    update_from_string = renamed_attr('update')
