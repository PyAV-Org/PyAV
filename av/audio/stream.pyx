cdef class AudioStream(Stream):

    def __repr__(self):
        return '<av.%s #%d %s at %dHz, %s, %s at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.name,
            self.rate,
            self.layout.name,
            self.format.name if self.format else None,
            id(self),
        )
