cimport libav as lib

from av.error cimport err_check
from av.frame cimport Frame
from av.packet cimport Packet


cdef class DataCodecContext(CodecContext):

    cpdef open(self, bint strict=True):

        if lib.avcodec_is_open(self.ptr):
            if strict:
                raise ValueError('CodecContext is already open.')
            return
