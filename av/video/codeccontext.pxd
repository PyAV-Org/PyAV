cimport libav as lib

from av.codec.context cimport CodecContext
from av.video.format cimport VideoFormat
from av.video.frame cimport VideoFrame
from av.video.reformatter cimport VideoReformatter


# The get_format callback in AVCodecContext is called by the decoder to pick a format out of a list.
# When we want accelerated decoding, we need to figure out ahead of time what the format should be,
# and find a way to pass that into our callback so we can return it to the decoder. We use the 'opaque'
# user data field in AVCodecContext for that. This is the struct we store a pointer to in that field.
cdef struct AVCodecPrivateData:
    lib.AVPixelFormat hardware_pix_fmt
    bint allow_software_fallback


cdef class VideoCodecContext(CodecContext):

    cdef AVCodecPrivateData _private_data

    cdef VideoFormat _format
    cdef _build_format(self)

    cdef int last_w
    cdef int last_h
    cdef readonly VideoReformatter reformatter

    # For encoding.
    cdef readonly int encoded_frame_count

    # For decoding.
    cdef VideoFrame next_frame
