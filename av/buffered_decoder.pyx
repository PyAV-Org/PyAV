from libc.stdlib cimport malloc, free, calloc

from av.container.streams cimport StreamContainer
from av.dictionary cimport _Dictionary
from av.packet cimport Packet
from av.stream cimport Stream, wrap_stream
from av.utils cimport err_check, avdict_to_dict
from av.frame cimport Frame
from av.video.frame cimport VideoFrame, alloc_video_frame, wrap_video_frame
from libc.errno cimport EAGAIN
from libc.stdio cimport printf

from av.utils import AVError # not cimport
from threading import Thread, Event, Semaphore, Lock, Event
from time import monotonic, sleep
cimport cython

import cysignals
#from cysignals.signals cimport sig_on, sig_off

cdef class CircularBuffer:
    def __cinit__(self,  buff_size):
        cdef int buffer_size = <int> buff_size + 1
        self.buffer = <lib.AVFrame**> calloc(buffer_size , sizeof(lib.AVFrame*))
        self.buffer_size = buffer_size
        self.buf_start = self.buf_end = 0
        self.frame_event = Event()
        self.last_pts = -1

    def __dealloc__(self):
        free(self.buffer)

    cdef:
        int count(self) nogil:
            if self.buf_start <= self.buf_end:
                return self.buf_end - self.buf_start
            else:
                return self.buffer_size - self.buf_start + self.buf_end
        int capacity(self) nogil:
            return self.buffer_size - 1
        bint empty(self) nogil:
            return self.count() is 0
        bint full(self) nogil:
            return self.count() is self.capacity()

        lib.AVFrame *get_next_free_slot(self) nogil:
            if self.count() > 0:
                return self.buffer[self.buf_end]

        bint add(self, lib.AVFrame *frame) nogil:
            if self.count() >= self.capacity():
                return False
            self.buffer[self.buf_end] = frame
            self.buf_end += 1
            self.buf_end = self.buf_end % self.buffer_size
            #if self.buf_end == self.dec_buffer_size:
            #    self.buf_end = 0
            return True
        lib.AVFrame *get(self) nogil:
            if self.count() == 0:
                return NULL
            cdef lib.AVFrame *frame = self.buffer[self.buf_start]
            self.buffer[self.buf_start] = NULL
            self.buf_start += 1
            if self.buf_start == self.buffer_size:
                self.buf_start = 0
            return frame
        void forward(self, int count):
            if count >= self.count():
                count = self.count() - 1
            self.buf_start = (self.buf_start + count) % self.buffer_size
        lib.AVFrame *at(self, int num):
            cdef int idx
            if num >= 0:
                return self.buffer[(self.buf_start + num) % self.buffer_size]
            else:
                idx = self.buf_end + num
                if idx < 0:
                    idx += self.buffer_size
                return self.buffer[idx]

        void add_buffer(self, CircularBuffer buf): # Source buffer gets emptied!
            frame = buf.get()
            while frame is not NULL:
                self.add(frame)
                frame = buf.get()
        void reset(self):
            self.buf_end = self.buf_start
            self.frame_event.clear()
            self.last_pts = -1











cdef class BufferedDecoder(object):
    def __cinit__(self,  container, stream,  dec_batch=30,  dec_buffer_size=50):
        #cdef int buf_size = <int> dec_buffer_size
        self.buffered_container = container
        self.buffered_stream = stream
        print("Starting buffer create")
        self.active_buffer = CircularBuffer(dec_buffer_size)
        self.standby_buffer = CircularBuffer(dec_buffer_size)
        self.backlog_buffer = CircularBuffer(2*dec_buffer_size)
        print("Created buffers")
        self.dec_batch = dec_batch
        self.external_seek = -1
        self.buffered_stream.seek(0)
        self.next_frame = self.decode(container, stream)
        f1, f2 = next(self.next_frame), next(self.next_frame)
        self.pts_rate = f2.pts
        self.buffered_stream.seek(0)
        #self.next_frame = self.decode(container, stream)
        self.buffering_sem = Semaphore()
        self.buffering_lock = Lock()
        self.av_lock = Lock()
        self.eos = False
        self.buf_thread_inst = Thread(target=self.buffering_thread)
        self.buf_thread_inst.start()
        print("Started thread!")

    def decode(self, container, stream):
        """decode(streams=None, video=None, audio=None, subtitles=None, data=None)

        Yields a series of :class:`.Frame` from the given set of streams::

            for frame in container.decode():
                # Do something with `frame`.

        .. seealso:: :meth:`.StreamContainer.get` for the interpretation of
            the arguments.

        """

        for packet in container.demux(stream):
            for frame in packet.decode():
                yield frame
    cpdef buffering_thread(self):
        cdef Frame frame
        cdef long long seek_target = -1
        cdef long long last_seek_target = -1
        cdef int num_frames = 0
        cdef double buf_begin_time = 0.
        cdef double buffering_time = 0.
        cdef int frames_to_buffer = 0
        cdef Packet packet
        cdef int ret
        cdef lib.AVPacket *packet_ptr
        cdef lib.AVFrame *avframe_ptr
        cdef CircularBuffer active_buffer
        cdef lib.AVFrame *last_frame
        cdef bint log = False
        cdef lib.AVFrame *unused_frame
        cdef int seek_frames = 0
        print("Starting buffering thread!")
        packet = Packet()
        while True:
            num_frames = 0
            self.buffering_sem.acquire()

            buf_begin_time = monotonic()
            self.av_lock.acquire()
            active_buffer = self.active_buffer
            seek_target = self.external_seek
            frames_to_buffer = self.dec_batch - active_buffer.count()
            #print("frames to buffer = {}".format(frames_to_buffer))
            self.av_lock.release()
            with nogil:
                while frames_to_buffer > 0 and seek_target == self.external_seek:
                    if seek_target != last_seek_target:
                        self.eos = False
                        last_seek_target = seek_target
                        with gil:
                            if log:
                                printf("Thread Seeking to %ld",seek_target)
                            self.buffered_stream.seek(seek_target)
                            seek_frames = 0
                            #if seek_target > 0:
                            #    log = True
                            #ret = lib.av_seek_frame(self.buffered_container.proxy.ptr, self.buffered_stream._stream.index, seek_target, lib.AVSEEK_FLAG_BACKWARD)
                    elif self.eos:
                        break

                    last_frame = NULL
                    avframe_ptr = self.backlog_buffer.get()
                    if avframe_ptr is NULL:
                        avframe_ptr = lib.av_frame_alloc()
                    while not self.eos:
                        if log:
                            printf("Calling av_read_frame\n")
                        ret = lib.av_read_frame(self.buffered_container.proxy.ptr, &packet.struct)
                        if ret < 0:
                            packet_ptr = NULL
                            if log:
                                printf("av_read_frame returned %d\n",ret)
                        else:
                            packet_ptr = &packet.struct #if not self.eos else NULL
                            if packet_ptr.stream_index != self.buffered_stream._stream.index:
                                continue

                        #with gil:
                        #    print("packet_ptr = {0:x} context ptr = {1:x}".format(<unsigned long>packet_ptr, <unsigned long> self.buffered_stream.codec_context.ptr))

                        ret = lib.avcodec_send_packet(self.buffered_stream.codec_context.ptr, packet_ptr)
                        if ret < 0 and log:
                            printf("avcodec_send_packet returned %d\n",ret)

                        ret = lib.avcodec_receive_frame(self.buffered_stream.codec_context.ptr, avframe_ptr)
                        if ret < 0 and log:
                            printf("avcodec_receive_frame returned %d\n",ret)

                        if not ret and avframe_ptr.pts >= seek_target:
                            last_frame = avframe_ptr
                            if seek_frames > 0:
                                printf("Seeked %d frames!\n", seek_frames)
                                seek_frames = 0
                            break
                        elif not ret:
                            seek_frames += 1
                        if ret is lib.AVERROR_EOF:
                            printf("End of stream!\n")
                            self.eos = True
                            break
                        #with gil:
                        #    print("receive_frame ret = {}".format(ret))
                        #if ret is -EAGAIN or lib.AVERROR_EOF:
                        #    if last_frame is not NULL:
                        #        #with gil:
                        #        #    print("Got frame: breaking")
                        #        break
                        if self.external_seek != seek_target:
                            self.backlog_buffer.add(avframe_ptr)
                            break
                    if last_frame is not NULL or self.eos is True:
                        if log:
                            printf("Adding to buffer frame %p", avframe_ptr)

                        unused_frame = active_buffer.get_next_free_slot()
                        if unused_frame is not NULL:
                            #with gil:
                            #    print("Reusing old frame {0:x}!".format(<unsigned long> unused_frame))
                            self.backlog_buffer.add(unused_frame)

                        active_buffer.add(last_frame)
                        if last_frame is not NULL:
                            active_buffer.last_pts = last_frame.pts
                        if active_buffer.count() == 1:
                             with gil:
                                 self.time_event = monotonic()
                                 active_buffer.frame_event.set()
                                 sleep(0)
                        if self.eos:
                            break
                    num_frames += 1
                    frames_to_buffer -= 1
            buffering_time = monotonic() - buf_begin_time
            if num_frames > 5:
                pass
                #print("Buffered {} frames for {}s!".format(num_frames, buffering_time))
        print("Ending buffering thread!")


    def get_frame(self):
        cdef Frame  frame = None
        cdef lib.AVFrame * av_frame
        cdef  double time_before_wait, time_wait
        while True:
            #print("get_frame av_frame = {0:x}".format(<unsigned long>av_frame))
            if self.active_buffer.empty():
                #print("Waiting for frame...")
                self.active_buffer.frame_event.wait()
                self.active_buffer.frame_event.clear()
                print("Time for thread switch {}s".format(monotonic() - self.time_event))
                #print("Got frame ={0:x}".format(<unsigned long>av_frame))

            av_frame = self.active_buffer.get()
            if av_frame is not NULL:
                self.buffering_sem.release()
                #frame = alloc_video_frame()
                #frame.ptr = av_frame
                frame = wrap_video_frame(av_frame)
                frame._init_user_attributes()
                self.buffered_stream.codec_context._setup_decoded_frame(frame)
                yield  frame
            else:
                print("av_frame is NULL")
                yield  None

    def seek(self, seek_pts):
        cdef long long seek_offset
        cdef int end_idx
        cdef CircularBuffer tmp_buf
        cdef lib.AVFrame *start_frm
        cdef lib.AVFrame *end_frm

        #end_idx = self.buf_end - 1
        #if end_idx < 0:
        #    end_idx = self.dec_buffer_size - 1


        ext_seek = False
        if self.active_buffer.count() < 3:
            ext_seek = True
        else:
            start_frm = self.active_buffer.at(0)
            if start_frm.pts < seek_pts < self.active_buffer.last_pts:
                #print("Seeking inside buffer!")
                seek_offset = self.pts_to_idx(seek_pts - start_frm.pts)
                self.active_buffer.forward(seek_offset)
            else:
                ext_seek = True
        if ext_seek:
            if self.active_buffer.count() > 2:
                print("Ext seek to {} last buf pts is {}".format(seek_pts, self.active_buffer.last_pts))
            self.standby_buffer.reset()

            self.av_lock.acquire()
            #switch buffers
            tmp_buf = self.active_buffer
            self.active_buffer = self.standby_buffer
            self.standby_buffer = tmp_buf
            self.external_seek = seek_pts
            self.av_lock.release()

            print("Switched buffers")

            self.buffering_sem.release()


    cdef long long pts_to_idx(self, long long pts):
        return pts // self.pts_rate
