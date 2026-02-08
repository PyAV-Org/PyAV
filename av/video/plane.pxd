from libc.stdint cimport int64_t, uint8_t, uint16_t, uint64_t

from av.plane cimport Plane
from av.video.format cimport VideoFormatComponent


cdef class VideoPlane(Plane):
    cdef readonly size_t buffer_size
    cdef readonly unsigned int width, height


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
