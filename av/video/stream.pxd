cimport libav as lib

from av.stream cimport Stream
from av.video.frame cimport VideoFrame
from av.video.swscontext cimport SwsContextProxy


cdef class VideoStream(Stream):
    
    cdef readonly int buffer_size
    
    # Hold onto the frames that we will decode until we have a full one.
    cdef lib.AVFrame *raw_frame
    cdef SwsContextProxy sws_proxy
    cdef int last_w
    cdef int last_h
    
    cdef int encoded_frame_count
    
    cpdef encode(self, VideoFrame frame=*)
