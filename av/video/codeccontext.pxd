
cimport libav as lib
from av.codec.context cimport CodecContext
from av.video.format cimport VideoFormat
from av.video.frame cimport VideoFrame
from av.video.reformatter cimport VideoReformatter


cdef class VideoCodecContext(CodecContext):

    cdef lib.AVPixelFormat _preferred_format

    cdef VideoFormat _last_format

    cdef int last_w
    cdef int last_h
    cdef readonly VideoReformatter reformatter

    # For encoding.
    cdef readonly int encoded_frame_count

    # For decoding.
    cdef VideoFrame next_frame
