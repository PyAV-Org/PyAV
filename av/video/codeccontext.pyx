from libc.stdint cimport int64_t

cimport libav as lib

from av.codec.context cimport CodecContext
from av.frame cimport Frame
from av.video.frame cimport VideoFrame, alloc_video_frame
from av.video.reformatter cimport VideoReformatter
from av.packet cimport Packet
from av.utils cimport err_check
from av.video.format cimport VideoFormat


cdef class VideoCodecContext(CodecContext):
    
    def __cinit__(self, *args, **kwargs):
        super(VideoCodecContext, self).__cinit__(*args, **kwargs)
        self.last_w = 0
        self.last_h = 0

    cpdef encode(self, Frame frame=None):
        """Encodes a frame of video, returns a packet if one is ready.

        The output packet does not necessarily contain data for the most recent frame, 
        as encoders can delay, split, and combine input frames internally as needed.
        If called with with no args it will flush out the encoder and return the buffered
        packets until there are none left, at which it will return None.

        """
        
        if not (isinstance(frame, VideoFrame) or frame is None):
            raise TypeError('frame must be None or VideoFrame')

        cdef VideoFrame vframe = frame

        if not self.is_open:

            # TODO codec-ctx: Only set these if not already set.
            # TODO codec-ctx: Assert frame is not None.
            self.ptr.pix_fmt = vframe.format.pix_fmt
            self.ptr.width = vframe.width
            self.ptr.height = vframe.height

            # TODO codec-ctx: Take these from the Frame's time_base.
            self.ptr.framerate.num = 30
            self.ptr.framerate.den = 1
            self.ptr.time_base.num = 1
            self.ptr.time_base.den = 30 

            self.open()

        if not self.reformatter:
            self.reformatter = VideoReformatter()

        cdef Packet packet = Packet()
        cdef int got_packet

        if vframe is not None:

            # Reformat if it doesn't match.
            if (vframe.format.pix_fmt != self.format.pix_fmt or
                vframe.width != self.ptr.width or
                vframe.height != self.ptr.height
            ):
                vframe.reformatter = self.reformatter
                vframe = vframe._reformat(
                    self.ptr.width,
                    self.ptr.height,
                    self.format.pix_fmt,
                    lib.SWS_CS_DEFAULT,
                    lib.SWS_CS_DEFAULT
                )

            if vframe.ptr.pts != lib.AV_NOPTS_VALUE:
                # It has a pts, so adjust it.
                # TODO: Don't mutate the frame.
                vframe.ptr.pts = lib.av_rescale_q(
                    vframe.ptr.pts,
                    vframe._time_base, #src
                    self.ptr.time_base,
                )
            
            else:
                # There is no pts, so create one.
                vframe.ptr.pts = <int64_t>self.encoded_frame_count
                
            self.encoded_frame_count += 1

            ret = err_check(lib.avcodec_encode_video2(self.ptr, &packet.struct, vframe.ptr, &got_packet))

        else:
            # Flushing
            ret = err_check(lib.avcodec_encode_video2(self.ptr, &packet.struct, NULL, &got_packet))

        if got_packet:
            # TODO codec-ctx: stream rebased pts/dts/duration from self.ptr.time_base to self._stream.time_base
            packet._time_base = self.ptr.time_base
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
        
        # Tell frame to finish constructing user properties.
        frame._init_properties()

        # Share our SwsContext with the frames. Most of the time they will end
        # up using the same settings as each other, so it makes sense to cache
        # it like this.
        # TODO codec-ctx: Stream did this.
        #frame.reformatter = self.reformatter

        return frame