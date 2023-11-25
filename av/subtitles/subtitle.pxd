cimport libav as lib

from av.packet cimport Packet


cdef class SubtitleProxy:

    cdef lib.AVSubtitle struct


cdef class SubtitleSet:

    cdef readonly Packet packet
    cdef SubtitleProxy proxy
    cdef readonly tuple rects


cdef class Subtitle:

    cdef SubtitleProxy proxy
    cdef lib.AVSubtitleRect *ptr
    cdef readonly bytes type

cdef class TextSubtitle(Subtitle):
    pass

cdef class ASSSubtitle(Subtitle):
    pass

cdef class BitmapSubtitle(Subtitle):

    cdef readonly planes

cdef class BitmapSubtitlePlane:

    cdef readonly BitmapSubtitle subtitle
    cdef readonly int index
    cdef readonly long buffer_size
    cdef void *_buffer
