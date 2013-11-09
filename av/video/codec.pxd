from av.codec cimport Codec
from av.video.format cimport VideoFormat


cdef class VideoCodec(Codec):
    
    cdef readonly VideoFormat format
    cdef readonly tuple planes
