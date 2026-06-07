from libc.stdint cimport int32_t, uint8_t

from av.packet cimport Packet
from av.stream cimport Stream

from .frame cimport VideoFrame


cdef class VideoStream(Stream):
    # Display matrix (9 int32, native-endian) written as AV_PKT_DATA_DISPLAYMATRIX
    # coded side data at mux time, applied only when _has_display_matrix is set.
    cdef int32_t _display_matrix[9]
    cdef uint8_t _has_display_matrix

    cdef _apply_display_matrix(self)

    cpdef encode(self, VideoFrame frame=?)
    cpdef decode(self, Packet packet=?)
