
cimport libav as lib

from av.codec.context cimport CodecContext
from av.video.format cimport VideoFormat
from av.video.frame cimport VideoFrame
from av.video.reformatter cimport VideoReformatter


cdef class VideoCodecContext(CodecContext):

    cdef VideoFormat _format
    cdef _build_format(self)

    cdef int last_w
    cdef int last_h
    cdef readonly VideoReformatter reformatter

    # For encoding.
    cdef readonly int encoded_frame_count

    # For decoding.
    cdef VideoFrame next_frame

    # For hardware acceleration
    cdef dict hwaccel
    cdef lib.AVPixelFormat hw_pix_fmt
    cdef lib.AVBufferRef* hw_device_ctx
    cdef bint _setup_hw_decoder(self, lib.AVCodec *codec)
