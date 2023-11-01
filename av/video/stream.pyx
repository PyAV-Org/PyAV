cdef class VideoStream(Stream):

    def __repr__(self):
        return '<av.%s #%d %s, %s %dx%d at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.name,
            self.format.name if self.format else None,
            self.codec_context.width,
            self.codec_context.height,
            id(self),
        )
