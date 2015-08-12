from libc.stdint cimport int64_t

from av.container.core cimport Container
from av.frame cimport Frame
from av.packet cimport Packet
from av.utils cimport avrational_to_faction, to_avrational
from av.utils cimport err_check
from av.video.format cimport get_video_format, VideoFormat
from av.video.frame cimport alloc_video_frame


cdef class VideoStream(Stream):
    
    cdef _init(self, Container container, lib.AVStream *stream):
        Stream._init(self, container, stream)
        self.last_w = 0
        self.last_h = 0
        self.encoded_frame_count = 0
        self._build_format()
        
    def __repr__(self):
        return '<av.%s #%d %s, %s %dx%d at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.name,
            self.format.name if self.format else None,
            self._codec_context.width,
            self._codec_context.height,
            id(self),
        )

    cdef _build_format(self):
        if self._codec_context:
            self.format = get_video_format(<lib.AVPixelFormat>self._codec_context.pix_fmt, self._codec_context.width, self._codec_context.height)
        else:
            self.format = None
        
    cdef _decode_one(self, lib.AVPacket *packet, int *data_consumed):
        
        # Create a frame if we don't have one ready.
        if not self.next_frame:
            self.next_frame = alloc_video_frame()

        # Decode video into the frame.
        cdef int completed_frame = 0
        
        cdef int result
        
        with nogil:
            result = lib.avcodec_decode_video2(self._codec_context, self.next_frame.ptr, &completed_frame, packet)
        data_consumed[0] = err_check(result)
        
        if not completed_frame:
            return
        
        # Check if the frame size has changed so that we can always have a
        # SwsContext that is ready to go.
        if self.last_w != self._codec_context.width or self.last_h != self._codec_context.height:
            
            self.last_w = self._codec_context.width
            self.last_h = self._codec_context.height
            
            self.buffer_size = lib.avpicture_get_size(
                self._codec_context.pix_fmt,
                self._codec_context.width,
                self._codec_context.height,
            )
            
            # Create a new SwsContextProxy
            self.reformatter = VideoReformatter()

        # We are ready to send this one off into the world!
        cdef VideoFrame frame = self.next_frame
        self.next_frame = None
        
        # Tell frame to finish constructing user properties.
        frame._init_properties()

        # Share our SwsContext with the frames. Most of the time they will end
        # up using the same settings as each other, so it makes sense to cache
        # it like this.
        frame.reformatter = self.reformatter

        return frame
    
    cpdef encode(self, VideoFrame frame=None):
        """Encodes a frame of video, returns a packet if one is ready.
        The output packet does not necessarily contain data for the most recent frame, 
        as encoders can delay, split, and combine input frames internally as needed.
        If called with with no args it will flush out the encoder and return the buffered
        packets until there are none left, at which it will return None.
        """
        
        # setup formatContext for encoding
        self._weak_container().start_encoding()
        
        if not self.reformatter:
            self.reformatter = VideoReformatter()
            
        cdef VideoFrame formated_frame
        cdef Packet packet
        cdef int got_output
        
        cdef VideoFormat pixel_format
        
        if frame:
            # don't reformat if format matches
            pixel_format = frame.format
            if pixel_format.pix_fmt == self.format.pix_fmt and \
                        frame.width == self._codec_context.width and frame.height == self._codec_context.height:
                formated_frame = frame
            else:
            
                frame.reformatter = self.reformatter
                formated_frame = frame._reformat(
                    self._codec_context.width,
                    self._codec_context.height,
                    self.format.pix_fmt,
                    lib.SWS_CS_DEFAULT,
                    lib.SWS_CS_DEFAULT
                )

        else:
            # Flushing
            formated_frame = None

        packet = Packet()
        packet.struct.data = NULL #packet data will be allocated by the encoder
        packet.struct.size = 0
        
        if formated_frame:
            
            # It has a pts, so adjust it.
            if formated_frame.ptr.pts != lib.AV_NOPTS_VALUE:
                formated_frame.ptr.pts = lib.av_rescale_q(
                    formated_frame.ptr.pts,
                    formated_frame.time_base, #src
                    self._codec_context.time_base,
                )
            
            # There is no pts, so create one.
            else:
                formated_frame.ptr.pts = <int64_t>self.encoded_frame_count
                
            
            self.encoded_frame_count += 1
            ret = err_check(lib.avcodec_encode_video2(self._codec_context, &packet.struct, formated_frame.ptr, &got_output))
        else:
            # Flushing
            ret = err_check(lib.avcodec_encode_video2(self._codec_context, &packet.struct, NULL, &got_output))

        if got_output:
            
            # rescale the packet pts and dts, which are in codec time_base, to the streams time_base

            if packet.struct.pts != lib.AV_NOPTS_VALUE:
                packet.struct.pts = lib.av_rescale_q(packet.struct.pts, 
                                                         self._codec_context.time_base,
                                                         self._stream.time_base)
            if packet.struct.dts != lib.AV_NOPTS_VALUE:
                packet.struct.dts = lib.av_rescale_q(packet.struct.dts, 
                                                     self._codec_context.time_base,
                                                     self._stream.time_base)
                
            if packet.struct.duration != lib.AV_NOPTS_VALUE:
                packet.struct.duration = lib.av_rescale_q(packet.struct.duration, 
                                                     self._codec_context.time_base,
                                                     self._stream.time_base)
                
            if self._codec_context.coded_frame:
                if self._codec_context.coded_frame.key_frame:
                    packet.struct.flags |= lib.AV_PKT_FLAG_KEY
                
            packet.struct.stream_index = self._stream.index
            packet.stream = self

            return packet

    property average_rate:
        def __get__(self): return avrational_to_faction(&self._stream.avg_frame_rate)

    property gop_size:
        def __get__(self):
            return self._codec_context.gop_size if self._codec_context else None
        def __set__(self, int value):
            self._codec_context.gop_size = value

    property sample_aspect_ratio:
        def __get__(self):
            return avrational_to_faction(&self._codec_context.sample_aspect_ratio) if self._codec_context else None
        def __set__(self, value):
            to_avrational(value, &self._codec_context.sample_aspect_ratio)
            
    property display_aspect_ratio:
        def __get__(self):
            cdef lib.AVRational dar
            
            lib.av_reduce(
                &dar.num, &dar.den,
                self._codec_context.width * self._codec_context.sample_aspect_ratio.num,
                self._codec_context.height * self._codec_context.sample_aspect_ratio.den, 1024*1024)

            return avrational_to_faction(&dar)

    property has_b_frames:
        def __get__(self):
            if self._codec_context.has_b_frames:
                return True
            return False

    property coded_width:
        def __get__(self):
            return self._codec_context.coded_width if self._codec_context else None

    property coded_height:
        def __get__(self):
            return self._codec_context.coded_height if self._codec_context else None

    property width:
        def __get__(self):
            return self._codec_context.width if self._codec_context else None
        def __set__(self, unsigned int value):
            self._codec_context.width = value
            self._build_format()

    property height:
        def __get__(self):
            return self._codec_context.height if self._codec_context else None
        def __set__(self, unsigned int value):
            self._codec_context.height = value
            self._build_format()

    # TEMPORARY WRITE-ONLY PROPERTIES to get encoding working again.
    property pix_fmt:
        def __set__(self, value):
            self._codec_context.pix_fmt = lib.av_get_pix_fmt(value)
            self._build_format()
