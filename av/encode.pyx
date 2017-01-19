from av.utils cimport err_check
from av.packet cimport Packet
from av.frame cimport Frame

from fractions import Fraction

cdef class Encoder(CodecContext):

    def __init__(self, str codec_name not None):

        cdef lib.AVCodec *codec
        codec = lib.avcodec_find_encoder_by_name(codec_name)
        if not codec:
            codec_descriptor = lib.avcodec_descriptor_get_by_name(codec_name)
            if codec_descriptor:
                codec = lib.avcodec_find_encoder(codec_descriptor.id)
        if not codec:
            raise ValueError("unknown encoding codec: %r" % codec_name)

        self.ptr = lib.avcodec_alloc_context3(codec)
        if not self.ptr:
            raise MemoryError("cannot allocate AVCodecContext")

        err_check(lib.avcodec_get_context_defaults3(self.ptr, codec))

        # older version of ffmpeg (2.2.4) don't set codec ptr
        if not self.ptr.codec:
            self.ptr.codec = codec

        self.fifo = None
        self._container = None
        self.options = {}

    cdef encode_video_frame(self, VideoFrame frame=None):
        cdef int got_output = 0
        cdef int ret = 0
        cdef lib.AVFrame *frame_ptr = frame.ptr if frame else NULL #Null for flush
        cdef Packet packet = Packet()

        if frame:
            if frame.ptr.format != self.ptr.pix_fmt:
                raise ValueError('incorrect pix_fmt: "%s" expected: "%s"' %
                                         (frame.format.name, self.pix_fmt))
            if frame.ptr.width != self.ptr.width or frame.ptr.height != self.ptr.height:
                raise ValueError('incorrect size: "%dx%d" expected: "%dx%d"' %
                                         (frame.ptr.width,frame.ptr.height,
                                          self.ptr.width,self.ptr.height))

        with nogil:
            ret = lib.avcodec_encode_video2(self.ptr, &packet.struct, frame_ptr, &got_output)
        err_check(ret)

        if got_output:
            return packet

    cdef encode_audio_frame(self, AudioFrame frame=None):
        cdef int got_output = 0
        cdef int ret = 0
        cdef lib.AVFrame *frame_ptr = frame.ptr if frame else NULL #Null for flush
        cdef Packet packet = Packet()

        with nogil:
            ret = lib.avcodec_encode_audio2(self.ptr, &packet.struct, frame_ptr, &got_output)
        err_check(ret)

        if got_output:
            return packet

    def process_audio_frame(self, AudioFrame frame=None):

        # use fifo if codec doesn't support variable frame size
        cdef bint use_fifo = not self.ptr.codec.capabilities & lib.CODEC_CAP_VARIABLE_FRAME_SIZE
        cdef int frame_size = self.ptr.frame_size

        if frame:
            if frame.ptr.format != self.ptr.sample_fmt:
                raise ValueError('incorrect sample_fmt: "%s" expected: "%s"' %
                                         (frame.format.name, self.sample_fmt))

            if frame.ptr.sample_rate != self.ptr.sample_rate:
                raise ValueError("incorrect sample rate: %d expected: %d" %
                                          (frame.ptr.sample_rate, self.sample_rate))

            if frame.nb_channels != self.ptr.channels:
                raise ValueError("incorrect channel count: %d expected: %d" %
                                        (frame.nb_channels, self.ptr.channels))

            if use_fifo:
                if not self.fifo:
                    self.fifo = AudioFifo()
                self.fifo.write(frame)
            else:
                yield frame

        if use_fifo:
            for f in self.fifo.iter(frame_size, partial = frame is None):
                yield f

    def encode(self, Frame frame=None):
        if not lib.avcodec_is_open(self.ptr):
            self.open()

        if self.ptr.codec_type == lib.AVMEDIA_TYPE_VIDEO:
            packet = self.encode_video_frame(frame)
            if frame is None:
                while packet:
                    yield packet
                    packet =  self.encode_video_frame(None)
            elif packet:
                yield packet

        elif self.ptr.codec_type == lib.AVMEDIA_TYPE_AUDIO:
            for f in self.process_audio_frame(frame):
                packet = self.encode_audio_frame(f)
                if packet:
                    yield packet

            if frame is None:
                packet = self.encode_audio_frame(None)
                while packet:
                    yield packet
                    packet = self.encode_audio_frame(None)
        else:
            raise NotImplementedError("%s encoding not implemented yet" % self.type)

    def flush(self):
        for packet in self.encode(None):
            yield packet
