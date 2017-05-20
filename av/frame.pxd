cimport libav as lib

from av.packet cimport Packet


cdef class Frame(object):

    cdef lib.AVFrame *ptr

    # We define our own time.
    cdef lib.AVRational _time_base
    cdef _rebase_time(self, lib.AVRational)

    cdef readonly int index

    cdef readonly tuple planes
    cdef _init_planes(self, cls=?)
    cdef int _max_plane_count(self)

    cdef _copy_attributes_from(self, Frame source, bint pts=?)
    
    cdef _init_properties(self)
    

