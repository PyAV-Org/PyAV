from av.audio.format cimport get_audio_format
from av.audio.frame cimport alloc_audio_frame
from av.audio.layout cimport get_audio_layout
from av.container cimport Container
from av.frame cimport Frame
from av.packet cimport Packet
from av.utils cimport err_check


cdef class AudioStream(Stream):

    cdef _init(self, Container container, lib.AVStream *stream):
        Stream._init(self, container, stream)
        self.encoded_frame_count = 0
        
        # Sometimes there isn't a layout set, but there are a number of
        # channels. Assume it is the default layout.
        self.layout = get_audio_layout(self._codec_context.channels, self._codec_context.channel_layout)
        if not self._codec_context.channel_layout:
            self._codec_context.channel_layout = self.layout.layout

        self.format = get_audio_format(self._codec_context.sample_fmt)
    
    def __repr__(self):
        return '<av.%s %s at %dHz, %s, %s at 0x%x>' % (
            self.__class__.__name__,
            self.name,
            self.rate,
            self.layout.name,
            self.format.name,
            id(self),
        )

    property frame_size:
        """Number of samples per channel in an audio frame."""
        def __get__(self): return self._codec_context.frame_size
        
    property rate:
        """samples per second """
        def __get__(self): return self._codec_context.sample_rate
        def __set__(self, int value): self._codec_context.sample_rate = value

    property channels:
        def __get__(self):
            return self._codec_context.channels
        
    cdef _decode_one(self, lib.AVPacket *packet, int *data_consumed):

        if not self.next_frame:
            self.next_frame = alloc_audio_frame()

        cdef int completed_frame = 0
        data_consumed[0] = err_check(lib.avcodec_decode_audio4(self._codec_context, self.next_frame.ptr, &completed_frame, packet))
        if not completed_frame:
            return
        
        cdef AudioFrame frame = self.next_frame
        self.next_frame = None
        
        frame._init_properties()
        
        return frame
    
    cpdef encode(self, AudioFrame frame=None):
        """Encodes a frame of audio, returns a packet if one is ready.
        The output packet does not necessarily contain data for the most recent frame, 
        as encoders can delay, split, and combine input frames internally as needed.
        If called with with no args it will flush out the encoder and return the buffered
        packets until there are none left, at which it will return None.
        """
        
        # setup formatContext for encoding
        self.weak_ctx().start_encoding()
        
        #Setup a resampler if ones not setup
        if not self.resampler:
            self.resampler = AudioResampler()
        
        # setup audio fifo if ones not setup
        if not self.fifo:
            self.fifo = AudioFifo(self.codec.channel_layout,
                self.codec.sample_fmt,
                self.codec.sample_rate,
                self.codec.frame_size,
            )
            self.fifo.add_silence = True
            
        cdef Packet packet
        cdef AudioFrame fifo_frame
        cdef int got_output
        
        flushing_and_samples = False
        
        # if frame supplied add to audio fifo
        if frame:
            frame.resampler = self.resampler
            self.fifo.write(frame)

        # read a frame out of the fifo queue if there are enough samples ready
        if frame and self.fifo.samples > self.codec.frame_size:
            fifo_frame = self.fifo.read(self.codec.frame_size)
        
        # if no frame (flushing) supplied get whats left of the audio fifo
        elif not frame and self.fifo.samples:
            fifo_frame = self.fifo.read(self.codec.frame_size)
            flushing_and_samples = True
            
        # if no frames are left in the audio fifo set fifo_frame to None to flush out encoder
        elif not frame:
            fifo_frame = None    
        else:
            return
        
        packet = Packet()
        packet.struct.data = NULL #packet data will be allocated by the encoder
        packet.struct.size = 0
        
        if fifo_frame:
            
            # if the fifo_frame has a valid pts scale it to the codecs time_base
            # the audio fifo time_base is always 1/sample_rate
            
            if fifo_frame.ptr.pts != lib.AV_NOPTS_VALUE:
                fifo_frame.ptr.pts = lib.av_rescale_q(fifo_frame.ptr.pts, 
                                                      fifo_frame.time_base_, #src 
                                                      self._codec_context.time_base) #dest
            else:
                fifo_frame.ptr.pts = lib.av_rescale(self.encoded_frame_count,
                                                    self._codec_context.sample_rate, #src
                                                    self._codec_context.time_base.den) #dest
                
            self.encoded_frame_count += fifo_frame.samples
            #print self.encoded_frame_count
            
            ret = err_check(lib.avcodec_encode_audio2(self._codec_context, &packet.struct, fifo_frame.ptr, &got_output))
        else:
            # frame set to NULL to flush encoder out frame
            ret = err_check(lib.avcodec_encode_audio2(self._codec_context, &packet.struct, NULL, &got_output))

        if got_output:
            
            # rescale the packet pts, dts and duration, which are in codec time_base, to the streams time_base
        
            if packet.struct.pts != lib.AV_NOPTS_VALUE:
                #print packet.struct.pts, '->',
                packet.struct.pts = lib.av_rescale_q(packet.struct.pts, 
                                                     self._codec_context.time_base,
                                                     self.ptr.time_base)
                #print packet.struct.pts, self._codec_context.time_base, self.ptr.time_base, self.ptr.start_time,self.codec.frame_rate

            if packet.struct.dts != lib.AV_NOPTS_VALUE:
                packet.struct.dts = lib.av_rescale_q(packet.struct.dts, 
                                                     self._codec_context.time_base,
                                                     self.ptr.time_base)

            if packet.struct.duration > 0:
                packet.struct.duration = lib.av_rescale_q(packet.struct.duration, 
                                                     self._codec_context.time_base,
                                                     self.ptr.time_base)
                
            if self._codec_context.coded_frame.key_frame:
                packet.struct.flags |= lib.AV_PKT_FLAG_KEY

            packet.struct.stream_index = self.ptr.index
            packet.stream = self
            
            return packet
        
        if flushing_and_samples:
            # if we got here we are flushing but there was still audio in the fifo queue
            # and encode_audio did not return a packet, call encode again to get a packet
            return self.encode()

