cimport libav as lib
from libc.stdint cimport uint8_t

from av.frame cimport Frame
from av.video.format cimport VideoFormat
from av.video.reformatter cimport VideoReformatter


cdef class CudaContext:
    cdef readonly int device_id
    cdef readonly bint primary_ctx
    cdef lib.AVBufferRef* _device_ref
    cdef dict _frames_cache
    cdef lib.AVBufferRef* _get_device_ref(self)
    cdef public lib.AVBufferRef* get_frames_ctx(
        self, lib.AVPixelFormat sw_fmt, int width, int height
    )

cdef class VideoFrame(Frame):
    cdef CudaContext _cuda_ctx
    cdef VideoReformatter reformatter
    cdef readonly VideoFormat format
    cdef readonly int _device_id
    cdef _init(self, lib.AVPixelFormat format, unsigned int width, unsigned int height)
    cdef _init_user_attributes(self)
    cpdef save(self, object filepath)

cdef VideoFrame alloc_video_frame()
