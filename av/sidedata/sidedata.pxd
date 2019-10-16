
from av.frame cimport Frame
from av.buffer cimport Buffer
cimport libav as lib


cdef class SideData(Buffer):

    cdef Frame frame
    cdef lib.AVFrameSideData *ptr


cdef SideData wrap_side_data(Frame frame, int index)

cdef class _SideDataContainer(object):

    cdef Frame frame

    cdef list _by_index
    cdef dict _by_type

