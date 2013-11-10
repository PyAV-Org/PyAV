cimport libav as lib

from av.audio.fifo cimport AudioFifo
from av.audio.format cimport AudioFormat
from av.audio.frame cimport AudioFrame
from av.audio.layout cimport AudioLayout
from av.audio.swrcontext cimport SwrContextProxy
from av.stream cimport Stream


cdef class AudioStream(Stream):

    cdef readonly AudioLayout layout
    cdef readonly AudioFormat format
    
    # Hold onto the frames that we will decode until we have a full one.
    cdef AudioFrame next_frame
    cdef SwrContextProxy swr_proxy
    cdef AudioFifo fifo
    cdef int encoded_frame_count
    
    cpdef encode(self, AudioFrame frame=*)
