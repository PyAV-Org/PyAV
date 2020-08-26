from libc.stdint cimport int64_t
cimport libav as lib

from av.container.core cimport Container
from av.utils cimport avrational_to_fraction


cdef class VideoStream(Stream):

    def __repr__(self):
        return '<av.%s #%d %s, %s %dx%d at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.name,
            self.format.name if self.format else None,
            self._codec_context.width,
            self._codec_context.height,
            id(self),
        )

    property average_rate:
        def __get__(self):
            return avrational_to_fraction(&self._stream.avg_frame_rate)
