from libc.stdlib cimport malloc, free

from av.container.streams cimport StreamContainer
from av.dictionary cimport _Dictionary
from av.packet cimport Packet
from av.stream cimport Stream, wrap_stream
from av.utils cimport err_check, avdict_to_dict
from av.frame cimport Frame
from av.video.frame cimport VideoFrame


from av.utils import AVError # not cimport
from threading import Thread, Event, Semaphore, Lock, Event
from time import monotonic, sleep
cimport cython

cdef class BufferedDecoder(object):
    def __cinit__(self,  container, stream, dec_batch=30, dec_buffer_size=50):
        self.buffered_container = container
        self.buffered_stream = stream
        self.decoded_buffer = dec_buffer_size  * [None]
        self.dec_batch = dec_batch
        self.dec_buffer_size = dec_buffer_size
        self.buf_start = 0
        self.buf_end = 0
        self.external_seek = -1
        self.buffered_stream.seek(0)
        self.next_frame = self.decode(container, stream)
        f1, f2 = next(self.next_frame), next(self.next_frame)
        self.pts_rate = f2.pts
        self.buffered_stream.seek(0)
        self.next_frame = self.decode(container, stream)
        self.buffering_sem = Semaphore()
        self.buffering_lock = Lock()
        self.av_lock = Lock()
        self.frame_event = Event()
        self.buf_thread_inst = Thread(target=self.buffering_thread)
        self.buf_thread_inst.start()

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
    def buffering_thread(self):
        cdef Frame frame
        cdef long seek_target = -1
        cdef int num_frames = 0
        cdef double buf_begin_time = 0.
        cdef double buffering_time = 0.
        cdef int frames_to_buffer = 0
        print("Starting buffering thread!")
        while True:
            num_frames = 0
            self.buffering_sem.acquire()
            buf_begin_time = monotonic()
            frames_to_buffer = self.dec_batch - self.num_frames_in_buffer()

            while frames_to_buffer > 0 or self.external_seek >= 0:
                if self.external_seek >= 0:
                    num_frames = 0

                self.av_lock.acquire()
                logged = False
                for frame in self.next_frame:
                    if frame.pts >= self.external_seek:
                        if self.external_seek >= 0:
                            #print("Finished seek")
                            self.external_seek = -1
                        break
                    elif not logged:
                        print("frames to seek {}".format((self.external_seek-frame.pts)/self.pts_rate))
                        logged = True
                self.av_lock.release()

                if frame is None:
                    print("Frame is None!")
                    last_buf_frame = self.decoded_buffer[self.buf_frame_num_to_idx(-1)]
                    if last_buf_frame is None:
                        break

                self.buffering_lock.acquire()
                if self.external_seek >=0:
                    self.buffering_lock.release()
                    break

                self.decoded_buffer[self.buf_end] = frame
                self.buf_end += 1
                if self.buf_end == self.dec_buffer_size:
                    self.buf_end = 0
                if self.buf_end == self.buf_start:
                    print("buf_end = buf_start")
                    self.buf_end -= 1
                self.buffering_lock.release()
                self.frame_event.set()
                sleep(0)
                num_frames += 1
                frames_to_buffer -= 1
            buffering_time = monotonic() - buf_begin_time
            if num_frames > 5:
                pass
                #print("Buffered {} frames for {}s!".format(num_frames, buffering_time))
        print("Ending buffering thread!")


    def get_frame(self):
        cdef Frame  frame = None
        cdef  double time_before_wait, time_wait
        while True:
            if self.num_frames_in_buffer() == 0:
                self.av_lock.acquire()
                if self.num_frames_in_buffer() == 0:
                    for frame in self.next_frame:
                        if frame.pts >= self.external_seek:
                            if self.external_seek > 0:
                                #print("Finished seek")
                                self.external_seek = -1
                            break
                        elif not logged:
                            print("main thread frames to seek {}".format((self.external_seek-frame.pts)/self.pts_rate))
                            logged = True
                self.av_lock.release()
            if self.num_frames_in_buffer() > 0 :
                frame = self.decoded_buffer[self.buf_start]
                self.decoded_buffer[self.buf_start] = None
                self.buf_start += 1
                if self.buf_start == self.dec_buffer_size:
                    self.buf_start = 0
            self.buffering_sem.release()
            yield  frame

    def seek(self, seek_pts):
        cdef int seek_offset
        cdef int end_idx
        self.buffering_lock.acquire()

        #end_idx = self.buf_end - 1
        #if end_idx < 0:
        #    end_idx = self.dec_buffer_size - 1


        ext_seek = False
        if self.num_frames_in_buffer() < 3:
            ext_seek = True
        else:
            end_idx = self.buf_frame_num_to_idx(-1)
            if self.decoded_buffer[end_idx] is None:
                end_idx = self.buf_frame_num_to_idx(-2)
            if self.decoded_buffer[self.buf_start].pts < seek_pts < self.decoded_buffer[end_idx].pts:
                #print("Seeking inside buffer!")
                seek_offset = self.pts_to_idx(seek_pts - self.decoded_buffer[self.buf_start].pts)
                self.buf_start += seek_offset
                if self.buf_start >= self.dec_buffer_size:
                    self.buf_start -= self.dec_buffer_size
            else:
                ext_seek = True
        if ext_seek:
            if self.num_frames_in_buffer() > 2:
                print("Ext seek to {} last buf pts is {}".format(seek_pts, self.decoded_buffer[self.buf_frame_num_to_idx(-1)].pts))
            self.external_seek = seek_pts
            self.buf_start = self.buf_end = 0
            self.av_lock.acquire()
            self.buffered_stream.seek(self.external_seek)
            self.next_frame = self.decode(self.buffered_container, self.buffered_stream)
            self.av_lock.release()
            self.buffering_sem.release()
        self.buffering_lock.release()

    cdef int num_frames_in_buffer(self):
        if self.buf_start <= self.buf_end:
            return self.buf_end - self.buf_start
        else:
            return self.dec_buffer_size - self.buf_start + self.buf_end

    cdef int pts_to_idx(self, int pts):
        return pts // self.pts_rate

    @cython.cdivision(True)
    cdef int buf_frame_num_to_idx(self, int num):
        cdef int idx
        if num >= 0:
            return (self.buf_start + num) % self.dec_buffer_size
        else:
            idx = self.buf_end + num
            if idx < 0:
                idx += self.dec_buffer_size
            return idx
