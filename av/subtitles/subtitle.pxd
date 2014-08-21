cimport libav as lib

from av.packet cimport Packet


cdef class SubtitleProxy(object):

    cdef lib.AVSubtitle struct


cdef class SubtitleSet(object):
    
    cdef readonly Packet packet
    cdef SubtitleProxy proxy
    cdef readonly tuple rects


cdef class Subtitle(object):

    cdef SubtitleProxy proxy
    cdef lib.AVSubtitleRect *ptr
    cdef readonly bytes type

cdef class TextSubtitle(Subtitle):
    pass

cdef class ASSSubtitle(Subtitle):
    pass

cdef class BitmapSubtitle(Subtitle):
    pass
