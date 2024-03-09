cdef class AudioStream(Stream):
    def __repr__(self):
        form = self.format.name if self.format else None
        return (
            f"<av.{self.__class__.__name__} #{self.index} {self.name} at {self.rate}Hz,"
            f" {self.layout.name}, {form} at 0x{id(self):x}>"
        )
