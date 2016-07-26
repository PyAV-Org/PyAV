
from av.codec.context cimport CodecContext
from av.video.reformatter cimport VideoReformatter
from av.video.frame cimport VideoFrame


cdef class VideoCodecContext(CodecContext):

    cdef int last_w
    cdef int last_h

    cdef readonly VideoReformatter reformatter

    # For decoding.
    cdef VideoFrame next_frame
