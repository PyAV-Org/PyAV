import cython


@cython.cclass
class Plane(Buffer):
    """
    Base class for audio and video planes.

    See also :class:`~av.audio.plane.AudioPlane` and :class:`~av.video.plane.VideoPlane`.
    """

    def __cinit__(self, frame: Frame, index: cython.int):
        self.frame = frame
        self.index = index

    def __repr__(self):
        return (
            f"<av.{self.__class__.__name__} {self.buffer_size} bytes; "
            f"buffer_ptr=0x{self.buffer_ptr:x}; at 0x{id(self):x}>"
        )

    @cython.cfunc
    def _buffer_ptr(self) -> cython.p_void:
        return self.frame.ptr.extended_data[self.index]
