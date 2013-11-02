from libc.stdint cimport int64_t

from av.frame cimport Frame
from av.packet cimport Packet
from av.utils cimport err_check


cdef class VideoStream(Stream):
    
    def __cinit__(self, *args):
        self.last_w = 0
        self.last_h = 0
        self.encoded_frame_count = 0
        
    cdef Frame _decode_one(self, lib.AVPacket *packet, int *data_consumed):
        
        # Create a frame if we don't have one ready.
        if not self.next_frame:
            self.next_frame = VideoFrame()

        # Decode video into the frame.
        cdef int completed_frame = 0
        data_consumed[0] = err_check(lib.avcodec_decode_video2(self.codec.ctx, self.next_frame.ptr, &completed_frame, packet))
        if not completed_frame:
            return
        
        # Check if the frame size has changed so that we can always have a
        # SwsContext that is ready to go.
        if self.last_w != self.codec.ctx.width or self.last_h != self.codec.ctx.height:
            
            self.last_w = self.codec.ctx.width
            self.last_h = self.codec.ctx.height
            
            self.buffer_size = lib.avpicture_get_size(
                self.codec.ctx.pix_fmt,
                self.codec.ctx.width,
                self.codec.ctx.height,
            )
            
            # Create a new SwsContextProxy
            self.sws_proxy = SwsContextProxy()

        # We are ready to send this one off into the world!
        cdef VideoFrame frame = self.next_frame
        self.next_frame = None
        
        # Transfer some convenient attributes over.
        frame.buffer_size = self.buffer_size
        
        # Share our SwsContext with the frames. Most of the time they will end
        # up using the same settings as each other, so it makes sense to cache
        # it like this.
        frame.sws_proxy = self.sws_proxy

        return frame
    
    cpdef encode(self, VideoFrame frame=None):
        """Encodes a frame of video, returns a packet if one is ready.
        The output packet does not necessarily contain data for the most recent frame, 
        as encoders can delay, split, and combine input frames internally as needed.
        If called with with no args it will flush out the encoder and return the buffered
        packets until there are none left, at which it will return None.
        """
        
        # setup formatContext for encoding
        self.weak_ctx().start_encoding()
        
        if not self.sws_proxy:
            self.sws_proxy = SwsContextProxy()
            
        cdef VideoFrame formated_frame
        cdef Packet packet
        cdef int got_output
        
        if frame:
            frame.sws_proxy = self.sws_proxy
            formated_frame = frame.reformat(self.codec.width,self.codec.height, self.codec.pix_fmt)

        else:
            # Flushing
            formated_frame = None

        packet = Packet()
        packet.struct.data = NULL #packet data will be allocated by the encoder
        packet.struct.size = 0
        
        if formated_frame:
            
            if formated_frame.ptr.pts != lib.AV_NOPTS_VALUE:
                formated_frame.ptr.pts = lib.av_rescale_q(formated_frame.ptr.pts, 
                                                          formated_frame.time_base, #src 
                                                          self.codec.ctx.time_base) #dest
                                
            else:
                pts_step = 1/float(self.codec.frame_rate) * self.codec.ctx.time_base.den
                formated_frame.ptr.pts = <int64_t> (pts_step * self.encoded_frame_count)
                
            
            self.encoded_frame_count += 1
            ret = err_check(lib.avcodec_encode_video2(self.codec.ctx, &packet.struct, formated_frame.ptr, &got_output))
        else:
            # Flushing
            ret = err_check(lib.avcodec_encode_video2(self.codec.ctx, &packet.struct, NULL, &got_output))

        if got_output:
            
            # rescale the packet pts and dts, which are in codec time_base, to the streams time_base

            if packet.struct.pts != lib.AV_NOPTS_VALUE:
                packet.struct.pts = lib.av_rescale_q(packet.struct.pts, 
                                                         self.codec.ctx.time_base,
                                                         self.ptr.time_base)
            if packet.struct.dts != lib.AV_NOPTS_VALUE:
                packet.struct.dts = lib.av_rescale_q(packet.struct.dts, 
                                                     self.codec.ctx.time_base,
                                                     self.ptr.time_base)
            if self.codec.ctx.coded_frame.key_frame:
                packet.struct.flags |= lib.AV_PKT_FLAG_KEY
                
            packet.struct.stream_index = self.ptr.index
            packet.stream = self

            return packet

