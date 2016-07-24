
from av.codeccontext cimport CodecContext
from av.video.reformatter cimport VideoReformatter
from av.video.frame cimport VideoFrame


cdef class VideoCodecContext(CodecContext):

    cdef readonly VideoReformatter reformatter

    # For decoding.
    cdef VideoFrame next_frame