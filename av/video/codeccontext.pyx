from libc.stdint cimport int64_t

cimport libav as lib

from av.codec.context cimport CodecContext
from av.frame cimport Frame
from av.packet cimport Packet
from av.utils cimport avrational_to_faction, to_avrational
from av.utils cimport err_check
from av.video.format cimport get_video_format, VideoFormat
from av.video.frame cimport VideoFrame, alloc_video_frame
from av.video.reformatter cimport VideoReformatter



cdef class VideoCodecContext(CodecContext):

    def __cinit__(self, *args, **kwargs):
        self.last_w = 0
        self.last_h = 0

    cdef _init(self, lib.AVCodecContext *ptr, lib.AVCodec *codec):
        CodecContext._init(self, ptr, codec) # TODO: Can this be `super`?
        self._build_format()
        self.encoded_frame_count = 0

    cdef _set_default_time_base(self):
        self.ptr.time_base.num = self.ptr.framerate.den or 1
        self.ptr.time_base.den = self.ptr.framerate.num or lib.AV_TIME_BASE

    cdef _prepare_frames_for_encode(self, Frame input):

        if not input:
            return [None]

        cdef VideoFrame vframe = input

        if not self.reformatter:
            self.reformatter = VideoReformatter()

        # Reformat if it doesn't match.
        if (vframe.format.pix_fmt != self._format.pix_fmt or
            vframe.width != self.ptr.width or
            vframe.height != self.ptr.height
        ):
            vframe.reformatter = self.reformatter
            vframe = vframe._reformat(
                self.ptr.width,
                self.ptr.height,
                self._format.pix_fmt,
                lib.SWS_CS_DEFAULT,
                lib.SWS_CS_DEFAULT
            )

        # There is no pts, so create one.
        if vframe.ptr.pts == lib.AV_NOPTS_VALUE:
            vframe.ptr.pts = <int64_t>self.encoded_frame_count

        self.encoded_frame_count += 1

        return [vframe]

    cdef _encode(self, Frame frame):
        """Encodes a frame of video, returns a packet if one is ready.

        The output packet does not necessarily contain data for the most recent frame,
        as encoders can delay, split, and combine input frames internally as needed.
        If called with with no args it will flush out the encoder and return the buffered
        packets until there are none left, at which it will return None.

        """

        cdef VideoFrame vframe = frame


        cdef Packet packet = Packet()
        cdef int got_packet

        if vframe is not None:
            ret = err_check(lib.avcodec_encode_video2(self.ptr, &packet.struct, vframe.ptr, &got_packet))
        else:
            ret = err_check(lib.avcodec_encode_video2(self.ptr, &packet.struct, NULL, &got_packet))

        if got_packet:
            return packet

    cdef Frame _alloc_next_frame(self):
        return alloc_video_frame()

    cdef _setup_decoded_frame(self, Frame frame, Packet packet):
        CodecContext._setup_decoded_frame(self, frame, packet)
        cdef VideoFrame vframe = frame
        vframe._init_user_attributes()

    cdef _decode(self, lib.AVPacket *packet, int *data_consumed):

        # Create a frame if we don't have one ready.
        if not self.next_frame:
            self.next_frame = alloc_video_frame()

        # Decode video into the frame.
        cdef int completed_frame = 0

        cdef int result

        with nogil:
            result = lib.avcodec_decode_video2(self.ptr, self.next_frame.ptr, &completed_frame, packet)
        data_consumed[0] = err_check(result)

        if not completed_frame:
            return

        # Check if the frame size has changed so that we can always have a
        # SwsContext that is ready to go.
        if self.last_w != self.ptr.width or self.last_h != self.ptr.height:
            self.last_w = self.ptr.width
            self.last_h = self.ptr.height
            # TODO codec-ctx: Stream would calculate self.buffer_size here.
            self.reformatter = VideoReformatter()

        # We are ready to send this one off into the world!
        cdef VideoFrame frame = self.next_frame
        self.next_frame = None

        # Share our SwsContext with the frames. Most of the time they will end
        # up using the same settings as each other, so it makes sense to cache
        # it like this.
        # TODO codec-ctx: Stream did this.
        #frame.reformatter = self.reformatter

        return frame


    cdef _build_format(self):
        if self.ptr:
            self._format = get_video_format(<lib.AVPixelFormat>self.ptr.pix_fmt, self.ptr.width, self.ptr.height)
        else:
            self._format = None

    property format:
        def __get__(self):
            return self._format
        def __set__(self, VideoFormat format):
            self.ptr.pix_fmt = format.pix_fmt
            self.ptr.width = format.width
            self.ptr.height = format.height
            self._build_format() # Kinda wasteful.

    property width:
        def __get__(self):
            return self.ptr.width if self.ptr else None
        def __set__(self, unsigned int value):
            self.ptr.width = value
            self._build_format()

    property height:
        def __get__(self):
            return self.ptr.height if self.ptr else None
        def __set__(self, unsigned int value):
            self.ptr.height = value
            self._build_format()

    # TODO: Replace with `format`.
    property pix_fmt:
        def __get__(self):
            return self._format.name
        def __set__(self, value):
            self.ptr.pix_fmt = lib.av_get_pix_fmt(value)
            self._build_format()

    property framerate:
        def __get__(self):
            return avrational_to_faction(&self.ptr.framerate)
        def __set__(self, value):
            to_avrational(value, &self.ptr.framerate)

    property rate:
        """Another name for :attr:`framerate`."""
        def __get__(self):
            return self.framerate
        def __set__(self, value):
            self.framerate = value

    property gop_size:
        def __get__(self):
            return self.ptr.gop_size if self.ptr else None
        def __set__(self, int value):
            self.ptr.gop_size = value

    property sample_aspect_ratio:
        def __get__(self):
            return avrational_to_faction(&self.ptr.sample_aspect_ratio) if self.ptr else None
        def __set__(self, value):
            to_avrational(value, &self.ptr.sample_aspect_ratio)

    property display_aspect_ratio:
        def __get__(self):
            cdef lib.AVRational dar

            lib.av_reduce(
                &dar.num, &dar.den,
                self.ptr.width * self.ptr.sample_aspect_ratio.num,
                self.ptr.height * self.ptr.sample_aspect_ratio.den, 1024*1024)

            return avrational_to_faction(&dar)

    property has_b_frames:
        def __get__(self):
            if self.ptr.has_b_frames:
                return True
            return False

    property coded_width:
        def __get__(self):
            return self.ptr.coded_width if self.ptr else None

    property coded_height:
        def __get__(self):
            return self.ptr.coded_height if self.ptr else None
