cimport libav as lib

from av.codeccontext cimport CodecContext
from av.frame cimport Frame
from av.video.frame cimport VideoFrame, alloc_video_frame
from av.video.reformatter cimport VideoReformatter
from av.packet cimport Packet
from av.utils cimport err_check
from av.video.format cimport VideoFormat


cdef class VideoCodecContext(CodecContext):
    

    cpdef encode(self, Frame frame=None):
        """Encodes a frame of video, returns a packet if one is ready.
        The output packet does not necessarily contain data for the most recent frame, 
        as encoders can delay, split, and combine input frames internally as needed.
        If called with with no args it will flush out the encoder and return the buffered
        packets until there are none left, at which it will return None.
        """
        
        if not (isinstance(frame, VideoFrame) or frame is None):
            raise TypeError('frame must be None or VideoFrame')

        cdef VideoFrame vframe = frame # TODO

        if not self.is_open:
            self.ptr.pix_fmt = vframe.format.pix_fmt
            self.ptr.width = vframe.width
            self.ptr.height = vframe.height
            self.ptr.framerate.num = 30
            self.ptr.framerate.den = 1
            self.ptr.time_base.num = 1
            self.ptr.time_base.den = 30 

        self.open(strict=False)

        # if not self.reformatter:
            # self.reformatter = VideoReformatter()

        cdef Packet packet
        cdef int got_output
        
        cdef VideoFormat pixel_format
        
        # if frame:
        #     # don't reformat if format matches
        #     pixel_format = frame.format
        #     if pixel_format.pix_fmt == self.format.pix_fmt and \
        #                 frame.width == self.ptr.width and frame.height == self.ptr.height:
        #         formated_frame = frame
        #     else:
            
        #         frame.reformatter = self.reformatter
        #         formated_frame = frame._reformat(
        #             self.ptr.width,
        #             self.ptr.height,
        #             self.format.pix_fmt,
        #             lib.SWS_CS_DEFAULT,
        #             lib.SWS_CS_DEFAULT
        #         )

        # else:
        #     # Flushing
        #     formated_frame = None

        packet = Packet()
        packet.struct.data = NULL #packet data will be allocated by the encoder
        packet.struct.size = 0
        
        if vframe:
            
        #     # It has a pts, so adjust it.
        #     if formated_frame.ptr.pts != lib.AV_NOPTS_VALUE:
        #         formated_frame.ptr.pts = lib.av_rescale_q(
        #             formated_frame.ptr.pts,
        #             formated_frame._time_base, #src
        #             self.ptr.time_base,
        #         )
            
        #     # There is no pts, so create one.
        #     else:
        #         formated_frame.ptr.pts = <int64_t>self.encoded_frame_count
                
            
        #     self.encoded_frame_count += 1
            ret = err_check(lib.avcodec_encode_video2(self.ptr, &packet.struct, vframe.ptr, &got_output))
        else:
            # Flushing
            ret = err_check(lib.avcodec_encode_video2(self.ptr, &packet.struct, NULL, &got_output))

        if got_output:
            
        #     # rescale the packet pts and dts, which are in codec time_base, to the streams time_base

        #     if packet.struct.pts != lib.AV_NOPTS_VALUE:
        #         packet.struct.pts = lib.av_rescale_q(packet.struct.pts, 
        #                                                  self.ptr.time_base,
        #                                                  self._stream.time_base)
        #     if packet.struct.dts != lib.AV_NOPTS_VALUE:
        #         packet.struct.dts = lib.av_rescale_q(packet.struct.dts, 
        #                                              self.ptr.time_base,
        #                                              self._stream.time_base)
                
        #     if packet.struct.duration != lib.AV_NOPTS_VALUE:
        #         packet.struct.duration = lib.av_rescale_q(packet.struct.duration, 
        #                                              self.ptr.time_base,
        #                                              self._stream.time_base)
                
        #     if self.ptr.coded_frame:
        #         if self.ptr.coded_frame.key_frame:
        #             packet.struct.flags |= lib.AV_PKT_FLAG_KEY
                
        #     packet.struct.stream_index = self._stream.index
        #     packet.stream = self

            return packet

        
    cdef Frame _decode_one(self, lib.AVPacket *packet, int *data_consumed):
        
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
        
        # # Check if the frame size has changed so that we can always have a
        # # SwsContext that is ready to go.
        # if self.last_w != self.ptr.width or self.last_h != self.ptr.height:
            
        #     self.last_w = self.ptr.width
        #     self.last_h = self.ptr.height
            
        #     self.buffer_size = lib.avpicture_get_size(
        #         self.ptr.pix_fmt,
        #         self.ptr.width,
        #         self.ptr.height,
        #     )
            
        #     # Create a new SwsContextProxy
        #     self.reformatter = VideoReformatter()

        # We are ready to send this one off into the world!
        cdef VideoFrame frame = self.next_frame
        self.next_frame = None
        
        # Tell frame to finish constructing user properties.
        frame._init_properties()

        # Share our SwsContext with the frames. Most of the time they will end
        # up using the same settings as each other, so it makes sense to cache
        # it like this.
        # frame.reformatter = self.reformatter

        return frame