cimport libav as lib


cdef class SubtitleProxy:
    cdef lib.AVSubtitle struct

cdef class SubtitleSet:
    cdef SubtitleProxy proxy
    cdef readonly tuple rects

cdef class Subtitle:
    cdef SubtitleProxy proxy
    cdef lib.AVSubtitleRect *ptr
    cdef readonly bytes type

cdef class BitmapSubtitle(Subtitle):
    cdef readonly planes

cdef class BitmapSubtitlePlane:
    cdef readonly BitmapSubtitle subtitle
    cdef readonly int index
    cdef readonly long buffer_size
    cdef void *_buffer
