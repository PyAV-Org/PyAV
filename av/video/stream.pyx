cdef class VideoStream(Stream):
    def __repr__(self):
        return (
            f"<av.{self.__class__.__name__} #{self.index} {self.name}, "
            f"{self.format.name if self.format else None} {self.codec_context.width}x"
            f"{self.codec_context.height} at 0x{id(self):x}>"
        )
