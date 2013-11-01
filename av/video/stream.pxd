cimport libav as lib

from av.stream cimport Stream
from av.video.frame cimport VideoFrame
from av.video.swscontext cimport SwsContextProxy


cdef class VideoStream(Stream):
    
    cdef readonly int buffer_size
    
    # Hold onto the frames that we will decode until we have a full one.
    cdef VideoFrame next_frame

    # Common SwsContext shared with all frames.
    cdef SwsContextProxy sws_proxy

    # Size of the last frame. Used to determine if the sws_proxy should be
    # recreated.
    cdef int last_w
    cdef int last_h
    
    cdef int encoded_frame_count
    
    cpdef encode(self, VideoFrame frame=*)
