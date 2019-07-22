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
    cpdef buffering_thread(self)
    cdef:
        CircularBuffer active_buffer
        CircularBuffer standby_buffer
        CircularBuffer backlog_buffer
        int dec_batch
        int pts_rate
        long long external_seek
        bint eos
        object next_frame
        object buffering_sem
        object buffering_lock
        object av_lock
        object buf_thread_inst
        Stream buffered_stream
        Container buffered_container
        double time_event
        long long last_buffered_pts
        bint thread_exit
        bint seek_in_progress
        cdef CircularBuffer thread_active_buffer
