from libc.stdint cimport int64_t, uint8_t, uint16_t, uint64_t

from av.plane cimport Plane
from av.video.format cimport VideoFormatComponent


cdef class VideoPlane(Plane):
    # Geometry derived from the frame, recomputed by _refresh() whenever the
    # frame's dimensions or data pointer change (e.g. after apply_cropping()).
    cdef size_t _size
    cdef unsigned int _width, _height
    cdef int _seen_width, _seen_height, _seen_linesize
    cdef void *_seen_data
    cdef void _refresh(self)


cdef enum DeviceType:
    kCPU = 1
    kCuda = 2

cdef struct DLDataType:
    uint8_t code
    uint8_t bits
    uint16_t lanes

cdef struct DLTensor:
    void* data
    int device_type
    int device_id
    int ndim
    DLDataType dtype
    int64_t* shape
    int64_t* strides
    uint64_t byte_offset

cdef struct DLManagedTensor

ctypedef void (*DLManagedTensorDeleter)(DLManagedTensor*) noexcept nogil

cdef struct DLManagedTensor:
    DLTensor dl_tensor
    void* manager_ctx
    DLManagedTensorDeleter deleter
