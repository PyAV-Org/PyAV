from libc.stdint cimport uint8_t, uint16_t, int16_t, int32_t, uint64_t

cimport libav as lib

from av.frame cimport Frame
from av.video.format cimport VideoFormat
from av.video.reformatter cimport VideoReformatter


cdef struct AVMotionVector:
    int32_t 	source
    uint8_t 	w
    uint8_t 	h
    int16_t 	src_x
    int16_t 	src_y
    int16_t 	dst_x
    int16_t 	dst_y
    uint64_t 	flags
    int32_t     motion_x
    int32_t     motion_y
    uint16_t    motion_scale


cdef class VideoFrame(Frame):

    # This is the buffer that is used to back everything in the AVFrame.
    # We don't ever actually access it directly.
    cdef uint8_t *_buffer

    cdef VideoReformatter reformatter

    cdef readonly VideoFormat format

    cdef _init(self, lib.AVPixelFormat format, unsigned int width, unsigned int height)
    cdef _init_user_attributes(self)

    cdef _reformat(self, int width, int height, lib.AVPixelFormat format, int src_colorspace, int dst_colorspace)

    cdef _get_motion_vectors(self, int only_moving)

cdef VideoFrame alloc_video_frame()
