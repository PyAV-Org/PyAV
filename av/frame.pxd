cimport libav as lib

from av.packet cimport Packet
from av.sidedata.sidedata cimport _SideDataContainer


cdef class Frame:
    cdef lib.AVFrame *ptr
    # We define our own time.
    cdef lib.AVRational _time_base
    cdef _rebase_time(self, lib.AVRational)
    cdef _SideDataContainer _side_data
    cdef _copy_internal_attributes(self, Frame source, bint data_layout=?)
    cdef _init_user_attributes(self)
