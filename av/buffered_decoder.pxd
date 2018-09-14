cimport libav as lib

from av.container.core cimport Container
from av.stream cimport Stream
from av.video.frame cimport VideoFrame, alloc_video_frame
from threading import Thread, Event, Lock, Semaphore

cdef class CircularBuffer:
    cdef:
        lib.AVFrame** buffer
        int buf_start
        int buf_end
        int buffer_size
        int count(self) nogil
        int capacity(self) nogil
        bint add(self, lib.AVFrame *) nogil
        void add_buffer(self, CircularBuffer )
        void forward(self, int )
        void reset(self)
        bint empty(self) nogil
        bint full(self) nogil
        lib.AVFrame *get_next_free_slot(self) nogil
        lib.AVFrame *at(self, int)
        lib.AVFrame *get(self) nogil
        object frame_event
        long long last_pts



cdef class BufferedDecoder(object):
    cdef long long pts_to_idx(self, long long pts)
    cpdef buffering_thread(self)
    cdef CircularBuffer active_buffer
    cdef CircularBuffer standby_buffer
    cdef CircularBuffer backlog_buffer
    cdef int dec_batch
    cdef int pts_rate
    cdef long long external_seek
    cdef bint eos
    cdef object next_frame
    cdef object buffering_sem
    cdef object buffering_lock
    cdef object av_lock
    cdef object buf_thread_inst
    cdef Stream buffered_stream
    cdef Container buffered_container
    cdef double time_event
    cdef long long last_buffered_pts
