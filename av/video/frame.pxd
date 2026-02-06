cimport libav as lib
from libc.stdint cimport uint8_t

from av.frame cimport Frame
from av.video.format cimport VideoFormat
from av.video.reformatter cimport VideoReformatter


cdef class CudaContext:
    cdef public int device_id
    cdef public bool primary_ctx
    cdef lib.AVBufferRef* _device_ref
    cdef dict _frames_cache

    cdef lib.AVBufferRef* _get_device_ref(self)
    cdef public lib.AVBufferRef* get_frames_ctx(
        self,
        lib.AVPixelFormat sw_fmt,
        int width,
        int height,
    )

cdef class VideoFrame(Frame):
    # This is the buffer that is used to back everything in the AVFrame.
    # We don't ever actually access it directly.
    cdef uint8_t *_buffer
    cdef object _np_buffer

    cdef VideoReformatter reformatter
    cdef readonly VideoFormat format

    cdef _init(self, lib.AVPixelFormat format, unsigned int width, unsigned int height)
    cdef _init_user_attributes(self)
    cpdef save(self, object filepath)

cdef VideoFrame alloc_video_frame()
