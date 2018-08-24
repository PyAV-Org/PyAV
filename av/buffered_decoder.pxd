cimport libav as lib

from av.container.core cimport Container
from av.stream cimport Stream
from av.video.frame cimport VideoFrame
from threading import Thread, Event, Lock, Semaphore

cdef class BufferedDecoder(object):
    cdef int num_frames_in_buffer(self)
    cdef int pts_to_idx(self, int pts)
    cdef int buf_frame_num_to_idx(self, int num)
    cdef list decoded_buffer
    cdef int buf_start
    cdef int buf_end
    cdef int dec_batch
    cdef int dec_buffer_size
    cdef int pts_rate
    cdef long external_seek
    cdef object next_frame
    cdef object buffering_sem
    cdef object buffering_lock
    cdef object av_lock
    cdef object frame_event
    cdef object buf_thread_inst
    cdef Stream buffered_stream
    cdef Container buffered_container
