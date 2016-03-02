cimport libav as lib

from av.packet cimport Packet


cdef class Frame(object):

    cdef lib.AVFrame *ptr

    # Attributes from the stream.
    cdef lib.AVRational time_base
    cdef readonly int index

    cdef readonly tuple planes
    cdef _init_planes(self, cls=?)
    cdef int _max_plane_count(self)

    cdef _copy_attributes_from(self, Frame source)
    
    cdef _init_properties(self)
    

