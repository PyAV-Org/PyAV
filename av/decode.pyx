from libc.stdint cimport uint8_t
from av.utils cimport err_check
from av.packet cimport Packet
from av.frame cimport Frame
from av.audio.frame cimport alloc_audio_frame, AudioFrame
from av.video.frame cimport alloc_video_frame, VideoFrame
from av.subtitles.subtitle cimport SubtitleProxy, SubtitleSet

from fractions import Fraction

cdef class Decoder(CodecContext):

    def __init__(self, str codec_name not None):

        cdef lib.AVCodec *codec
        codec = lib.avcodec_find_decoder_by_name(codec_name)
        if not codec:
            codec_descriptor = lib.avcodec_descriptor_get_by_name(codec_name)
            if codec_descriptor:
                codec = lib.avcodec_find_decoder(codec_descriptor.id)
        if not codec:
            raise ValueError("unknown encoding codec: %r" % codec_name)

        self.ptr = lib.avcodec_alloc_context3(codec)
        if not self.ptr:
            raise MemoryError("cannot allocate AVCodecContext")

        err_check(lib.avcodec_get_context_defaults3(self.ptr, codec))

        # older version of ffmpeg (2.2.4) don't set codec ptr
        if not self.ptr.codec:
            self.ptr.codec = codec

        self.options = {}
        self._container = None
        self.next_frame = None

    cdef decode_video_frame(self, Packet packet, int *data_consumed):
        if not self.next_frame:
             self.next_frame = alloc_video_frame()

        cdef int completed_frame = 0
        cdef int ret = 0

        if not packet:
            packet = Packet()

        cdef lib.AVPacket *packet_ptr = &packet.struct

        with nogil:
             ret = lib.avcodec_decode_video2(self.ptr, self.next_frame.ptr, &completed_frame, packet_ptr)
        data_consumed[0] = err_check(ret)

        if not completed_frame:
             return

        cdef VideoFrame frame = self.next_frame
        self.next_frame = None

        frame._init_properties()

        return frame

    cdef decode_audio_frame(self, Packet packet, int *data_consumed):
        if not self.next_frame:
             self.next_frame = alloc_audio_frame()

        cdef int completed_frame = 0
        cdef int ret = 0

        if not packet:
            packet = Packet()

        cdef lib.AVPacket *packet_ptr = &packet.struct

        with nogil:
            ret = lib.avcodec_decode_audio4(self.ptr, self.next_frame.ptr, &completed_frame, packet_ptr)
        data_consumed[0] = err_check(ret)

        if not completed_frame:
            return

        cdef AudioFrame frame = self.next_frame
        self.next_frame = None

        frame._init_properties()

        return frame

    cdef decode_subtitle_frame(self, Packet packet, int *data_consumed):

        cdef int completed_frame = 0
        cdef int ret = 0
        cdef SubtitleProxy proxy = SubtitleProxy()
        if not packet:
            packet = Packet()

        cdef lib.AVPacket *packet_ptr = &packet.struct

        with nogil:
            ret = lib.avcodec_decode_subtitle2(self.ptr, &proxy.struct, &completed_frame, packet_ptr)
        err_check(ret)
        data_consumed[0] = packet.size

        if not completed_frame:
            return

        return SubtitleSet(proxy)

    cdef decode_one(self, Packet packet, int *data_consumed):
        if self.ptr.codec_type == lib.AVMEDIA_TYPE_VIDEO:
            return self.decode_video_frame(packet, data_consumed)
        elif self.ptr.codec_type == lib.AVMEDIA_TYPE_AUDIO:
            return self.decode_audio_frame(packet, data_consumed)
        elif self.ptr.codec_type == lib.AVMEDIA_TYPE_SUBTITLE:
            return self.decode_subtitle_frame(packet, data_consumed)
        else:
            raise NotImplementedError("%s decoding not implemented yet" % self.type)

    def decode(self, Packet packet=None):
        if not lib.avcodec_is_open(self.ptr):
            self.open()

        cdef int data_consumed = 0
        cdef uint8_t *original_data = packet.struct.data if packet else NULL
        cdef int      original_size = packet.struct.size if packet else 0

        try:
            if packet is None:
                frame = self.decode_one(None, &data_consumed)
                while frame:
                    yield frame
                    frame = self.decode_one(None, &data_consumed)

            else:
                while packet.struct.size > 0:
                    frame = self.decode_one(packet, &data_consumed)
                    if frame:
                        yield frame
                    packet.struct.size -= data_consumed
                    packet.struct.data += data_consumed

        finally:
            if packet:
                packet.struct.size = original_size
                packet.struct.data = original_data

    def flush(self):
        for frame in self.decode(None):
            yield frame
