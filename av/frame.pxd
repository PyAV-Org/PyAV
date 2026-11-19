cimport libav as lib

from av.packet cimport Packet


cdef class Frame:
    cdef lib.AVFrame *ptr
    # We define our own time.
    cdef lib.AVRational _time_base
    # The data is borrowed from a read-only Python object.
    cdef bint _readonly
    cdef _rebase_time(self, lib.AVRational)
    cdef _copy_internal_attributes(self, Frame source, bint data_layout=?)
    cdef _init_user_attributes(self)
