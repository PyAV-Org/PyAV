from libc.stdint cimport int64_t, uint8_t, uint16_t, uint64_t


cdef enum DLDeviceType:
    kDLCPU = 1
    kDLCUDA = 2

cdef enum DLDataTypeCode:
    kDLInt = 0
    kDLUInt = 1
    kDLFloat = 2
    kDLBfloat = 4
    kDLComplex = 5
    kDLBool = 6

cdef struct DLDevice:
    int device_type
    int device_id

cdef struct DLDataType:
    uint8_t code
    uint8_t bits
    uint16_t lanes

cdef struct DLTensor:
    void* data
    DLDevice device
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
