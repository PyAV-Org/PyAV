from av.utils cimport avrational_to_fraction


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

    property rate:
        """
        Returns the average_frame_rate of the stream.
        :type: :class:`~fractions.Fraction` or ``None``
        """
        def __get__(self):
            return avrational_to_fraction(&self.ptr.avg_frame_rate)

    property framerate:
        """
        Returns the average_frame_rate of the stream.
        :type: :class:`~fractions.Fraction` or ``None``
        """
        def __get__(self):
            return avrational_to_fraction(&self.ptr.avg_frame_rate)
