cimport libav as lib
from av.frame.audio cimport AudioFrame, AudioFifo
from av.codec cimport SwrContextProxy


cdef class AudioStream(Stream):

    # Hold onto the frames that we will decode until we have a full one.
    cdef lib.AVFrame *frame
    cdef SwrContextProxy swr_proxy
    cdef AudioFifo fifo
    cdef int encoded_frame_count
    
    cpdef encode(self, AudioFrame frame=*)
