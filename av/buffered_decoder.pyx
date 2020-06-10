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
IF UNAME_SYSNAME != "Windows":
    import cysignals

# NOTE: logging is shadowed by av.logging, which is imported in __init__.py
# But av.logging imports logging, so we can use that to access it.
from logging import logging
logger = logging.getLogger(__name__)
# logger.setLevel(logging.DEBUG)

# Since we should not use python logging in nogil sections of this code, we use
# printf. Whether to log debug messages or not can still be determined from
# logging's debug level!
cdef bint log_enabled = logger.getEffectiveLevel() == logging.DEBUG

cdef class CircularBuffer:
    def __cinit__(self,  buff_size):
        cdef int buffer_size = <int> buff_size + 1
        self.buffer = <lib.AVFrame**> calloc(buffer_size , sizeof(lib.AVFrame*))
        self.buffer_size = buffer_size
        self.buf_start = self.buf_end = 0
        self.frame_event = Event()
        self.last_pts = -1

    def __dealloc__(self):
        self.reset()
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
            
            for i in range(count):
                self._reset_index(i)
                
            self.buf_start = (self.buf_start + count) % self.buffer_size
        
        int _real_index(self, int num) nogil:
            cdef int idx
            if num >= 0:
                return (self.buf_start + num) % self.buffer_size
            else:
                idx = self.buf_end + num
                if idx < 0:
                    idx += self.buffer_size
                return idx

        lib.AVFrame *at(self, int num):
            return self.buffer[self._real_index(num)]

        void reset(self):
            cdef int i
            for i in range(self.buffer_size):
                self._reset_index(i)

            self.buf_end = self.buf_start
            self.frame_event.clear()
            self.last_pts = -1

        void _reset_index(self, int index) nogil:
            cdef int real_index = self._real_index(index)
            cdef lib.AVFrame *frame = self.buffer[real_index]
            if frame is not NULL:
                lib.av_frame_free(&frame)
                self.buffer[real_index] = NULL









cdef class BufferedDecoder(object):
    def __cinit__(self,  container, stream,  dec_batch=30,  dec_buffer_size=50):
        #cdef int buf_size = <int> dec_buffer_size
        self.buffered_container = container
        self.buffered_stream = stream
        #print("Starting buffer create")
        self.active_buffer = CircularBuffer(dec_buffer_size)
        self.standby_buffer = CircularBuffer(dec_buffer_size)
        self.backlog_buffer = CircularBuffer(2*dec_buffer_size)
        #print("Created buffers")
        self.dec_batch = dec_batch
        self.external_seek = -1
        self.buffered_stream.seek(0)
        self.buffering_sem = Semaphore()
        self.buffering_lock = Lock()
        self.av_lock = Lock()
        self.eos = False
        self.thread_exit = False
        self.seek_in_progress = False
        self.buf_thread_inst = Thread(target=self.buffering_thread)
        self.buf_thread_inst.start()
        #print("Started thread!")

    def stop_buffer_thread(self):
        self.thread_exit = True
        self.buffering_sem.release()
        self.buf_thread_inst.join()
        self.buf_thread_inst = None

    def __dealloc__(self):
        if self.buf_thread_inst:
            self.stop_buffer_thread()

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
        cdef lib.AVFrame *last_frame
        cdef lib.AVFrame *unused_frame
        cdef int seek_frames = 0
        logger.info("Starting buffering thread!")
        packet = Packet()
        while True:
            num_frames = 0
            self.buffering_sem.acquire()
            if self.thread_exit:
                return

            buf_begin_time = monotonic()
            self.av_lock.acquire()
            self.thread_active_buffer = self.active_buffer
            seek_target = self.external_seek
            frames_to_buffer = self.dec_batch - self.thread_active_buffer.count()
            logger.debug("frames to buffer = {}".format(frames_to_buffer))
            self.av_lock.release()
            with nogil:
                while frames_to_buffer > 0 and seek_target == self.external_seek:
                    if seek_target != last_seek_target:
                        self.eos = False
                        last_seek_target = seek_target
                        with gil:
                            logger.debug(f"Thread Seeking to {seek_target}")
                            self.buffered_stream.seek(seek_target)
                            self.seek_in_progress = True
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
                        if log_enabled:
                            printf("Calling av_read_frame\n")
                        ret = lib.av_read_frame(self.buffered_container.proxy.ptr, &packet.struct)
                        if ret < 0:
                            packet_ptr = NULL
                            if log_enabled:
                                printf("av_read_frame returned %d\n",ret)
                        else:
                            packet_ptr = &packet.struct #if not self.eos else NULL
                            if packet_ptr.stream_index != self.buffered_stream._stream.index:
                                continue

                        #with gil:
                        #    print("packet_ptr = {0:x} context ptr = {1:x}".format(<unsigned long>packet_ptr, <unsigned long> self.buffered_stream.codec_context.ptr))

                        ret = lib.avcodec_send_packet(self.buffered_stream.codec_context.ptr, packet_ptr)
                        if ret < 0 and log_enabled:
                            printf("avcodec_send_packet returned %d\n",ret)

                        ret = lib.avcodec_receive_frame(self.buffered_stream.codec_context.ptr, avframe_ptr)
                        if ret < 0 and log_enabled:
                            printf("avcodec_receive_frame returned %d\n",ret)

                        if not ret:
                            if avframe_ptr.pts >= seek_target:
                                last_frame = avframe_ptr
                                if seek_frames > 0:
                                    #printf("Seeked %d frames!\n", seek_frames)
                                    seek_frames = 0
                                if self.seek_in_progress:
                                    with gil, self.av_lock:
                                        self.seek_in_progress = False
                                        if self.external_seek == seek_target:
                                            seek_target = last_seek_target = self.external_seek = -1
                                break
                            else:
                                seek_frames += 1

                        if ret is lib.AVERROR_EOF:
                            if log_enabled:
                                printf("End of stream! last_frame is %p\n", last_frame)
                            self.eos = True
                            self.backlog_buffer.add(avframe_ptr)
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
                        if log_enabled:
                            printf("Adding to buffer frame %p", avframe_ptr)

                        unused_frame = self.thread_active_buffer.get_next_free_slot()
                        if unused_frame is not NULL:
                            #with gil:
                            #    print("Reusing old frame {0:x}!".format(<unsigned long> unused_frame))
                            self.backlog_buffer.add(unused_frame)

                        self.thread_active_buffer.add(last_frame)
                        if last_frame is not NULL:
                            self.thread_active_buffer.last_pts = last_frame.pts
                        if self.thread_active_buffer.count() == 1:
                             with gil:
                                 self.time_event = monotonic()
                                 self.thread_active_buffer.frame_event.set()
                                 sleep(0)
                        if self.eos:
                            break
                    num_frames += 1
                    frames_to_buffer -= 1
            buffering_time = monotonic() - buf_begin_time
            if num_frames > 5:
                pass
                #print("Buffered {} frames for {}s!".format(num_frames, buffering_time))
        logging.info("Ending buffering thread!")


    def get_frame(self):
        cdef Frame  frame = None
        cdef lib.AVFrame * av_frame
        cdef  double time_before_wait, time_wait
        while True:
            #print("get_frame av_frame = {0:x}".format(<unsigned long>av_frame))
            while self.active_buffer.empty():
                #print("Waiting for frame...")
                self.active_buffer.frame_event.wait()
                self.active_buffer.frame_event.clear()
                #print("Time for thread switch {}s".format(monotonic() - self.time_event))
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
                logging.debug("av_frame is NULL")
                yield  None

    def seek(self, seek_pts):
        cdef long long seek_offset
        cdef int end_idx
        cdef CircularBuffer tmp_buf
        cdef lib.AVFrame *start_frame
        cdef lib.AVFrame *tmp_frame

        #end_idx = self.buf_end - 1
        #if end_idx < 0:
        #    end_idx = self.dec_buffer_size - 1

        ext_seek = False
        if self.active_buffer.count() < 3:
            ext_seek = True
        else:
            start_frame = self.active_buffer.at(0)

            if not start_frame:
                # This should never happen if used correctly, but we can still
                # handle it gracefully.
                logger.error("Error accessing start frame!")
                ext_seek = True

            elif start_frame.pts <= seek_pts <= self.active_buffer.last_pts:
                # Binary search through buffer
                # TODO: Can be done more efficiently directly in the buffer.
                target_idx = -1
                left = 0
                right = self.active_buffer.count() - 1
                while left <= right:
                    mid = (left + right) // 2
                    tmp_frame = self.active_buffer.at(mid)
                    if tmp_frame.pts == seek_pts:
                        target_idx = mid
                        break
                    elif tmp_frame.pts < seek_pts:
                        left = mid + 1
                    else:
                        right = mid - 1

                if target_idx == -1:
                    logger.warn(f"Warn: no frame found with pts {seek_pts}! Taking next one!")
                    # TODO: determine closest one?
                    # Note: we know have right < left!
                    target_idx = left
                
                self.active_buffer.forward(target_idx)

            else:
                # seek_pts is not in buffer
                ext_seek = True

        if ext_seek:
            #if self.active_buffer.count() > 2:
            #    print("Ext seek to {} last buf pts is {}".format(seek_pts, self.active_buffer.last_pts))

            self.av_lock.acquire()
            if self.standby_buffer.buffer != self.thread_active_buffer.buffer:
                self.standby_buffer.reset()
                #switch buffers
                tmp_buf = self.active_buffer
                self.active_buffer = self.standby_buffer
                self.standby_buffer = tmp_buf
            self.external_seek = seek_pts
            self.av_lock.release()

            #print("Switched buffers")

            self.buffering_sem.release()
