from av.audio.fifo cimport AudioFifo
from av.audio.layout cimport blank_audio_layout
from av.audio.format cimport blank_audio_format
from av.audio.plane cimport AudioPlane

from av.utils cimport err_check


cdef object _cinit_bypass_sentinel = object()


cdef AudioFrame blank_audio_frame():
    return AudioFrame.__new__(AudioFrame, _cinit_bypass_sentinel)


cdef class AudioFrame(Frame):

    """A frame of audio."""
    
    def __cinit__(self, format='s16', layout='stereo', samples=0, align=True):
        if format is _cinit_bypass_sentinel:
            return
        raise NotImplementedError()

    cdef _init(self, lib.AVSampleFormat format, uint64_t layout, unsigned int nb_samples, bint align):

        self.align = align
        self.ptr.nb_samples = nb_samples
        self.ptr.format = <int>format
        self.ptr.channel_layout = layout
        
        cdef size_t buffer_size
        if self.format.channels and nb_samples:
            
            # Cleanup the old buffer.
            lib.av_freep(&self._buffer)

            # Get a new one.
            buffer_size = err_check(lib.av_samples_get_buffer_size(
                NULL,
                len(self.format.channels),
                nb_samples,
                format,
                align,
            ))
            self._buffer = <uint8_t *>lib.av_malloc(buffer_size)
            if not self._buffer:
                raise MemoryError("cannot allocate AudioFrame buffer")

            # Connect the buffer to the frame fields.
            err_check(lib.avcodec_fill_audio_frame(
                self.ptr, 
                len(self.format.channels), 
                <lib.AVSampleFormat>self.ptr.format,
                self._buffer,
                buffer_size,
                self.align
            ))

        self._init_properties()

    cdef _init_properties(self):
        self.layout = blank_audio_layout()
        self.layout._init(self.ptr.channel_layout)
        self.format = blank_audio_format()
        self.format._init(<lib.AVSampleFormat>self.ptr.format)

        self.nb_channels = lib.av_get_channel_layout_nb_channels(self.ptr.channel_layout)
        self.nb_planes = self.nb_channels if lib.av_sample_fmt_is_planar(<lib.AVSampleFormat>self.ptr.format) else 1
        self._init_planes(AudioPlane)

    def __dealloc__(self):
        lib.av_freep(&self._buffer)
    
    def __repr__(self):
        return '<%s.%s %d samples at %dHz, %s, %s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.samples,
            self.rate,
            self.layout.name,
            self.format.name,
            id(self),
        )
    
   
    def set_silence(self, int offset, int nb_samples):
        err_check(lib.av_samples_set_silence(self.ptr.extended_data,
                                             offset,
                                             nb_samples,
                                             self.channels,
                                             <lib.AVSampleFormat>self.ptr.format))
    

    cpdef resample(self, bytes channel_layout, bytes sample_fmt, int out_sample_rate):
        
        
        # Check params
        cdef uint64_t out_ch_layout = lib.av_get_channel_layout(channel_layout)
        if out_ch_layout == 0:
            raise ValueError("invalid channel layout %s" % channel_layout)
            
        cdef lib.AVSampleFormat out_sample_fmt = lib.av_get_sample_fmt(sample_fmt)
        if out_sample_fmt == lib.AV_SAMPLE_FMT_NONE:
            raise ValueError("invalid sample_fmt %s" % sample_fmt)
        
        if not self.swr_proxy:
            self.swr_proxy = SwrContextProxy()
        
        cdef int dst_nb_channels = lib.av_get_channel_layout_nb_channels(out_ch_layout)
            
        #print "source =", self.sample_rate, self.channel_layout,self.ptr.channel_layout, self.channels, self.sample_fmt,self.ptr.format
        #print "dest   =", out_sample_rate, channel_layout,out_ch_layout, dst_nb_channels, sample_fmt, out_sample_fmt

        if not self.swr_proxy.ptr:
            self.swr_proxy.ptr = lib.swr_alloc()
        
        err_check(lib.av_opt_set_int(self.swr_proxy.ptr, "in_channel_layout" ,self.ptr.channel_layout,0))
        err_check(lib.av_opt_set_int(self.swr_proxy.ptr, "out_channel_layout" ,out_ch_layout,0))
        
        err_check(lib.av_opt_set_int(self.swr_proxy.ptr, 'in_sample_rate', self.ptr.sample_rate, 0))
        err_check(lib.av_opt_set_int(self.swr_proxy.ptr, 'out_sample_rate', out_sample_rate, 0))
        
        err_check(lib.av_opt_set_int(self.swr_proxy.ptr, 'in_sample_fmt', self.ptr.format, 0))
        err_check(lib.av_opt_set_int(self.swr_proxy.ptr, 'out_sample_fmt', <int>out_sample_fmt, 0))
        
        err_check(lib.swr_init(self.swr_proxy.ptr))
        
        # helper names, just so I remember what they are       
        cdef int src_nb_samples = self.ptr.nb_samples
        cdef int src_rate = self.ptr.sample_rate
        
        # compute the number of converted samples
        cdef int dst_nb_samples = lib.av_rescale_rnd(src_nb_samples,
                                                 out_sample_rate, #dst sample rate
                                                 src_rate, # src sample rate
                                                 lib.AV_ROUND_UP)
        
        cdef AudioFrame frame
        
        # create a audio fifo queue to collect samples
        cdef AudioFifo fifo = AudioFifo(channel_layout,
                                        sample_fmt, 
                                        out_sample_rate,
                                        dst_nb_samples)
        
        flush = False
        
        # NOTE: for some reason avresample_convert won't return enough converted samples if src_nb_samples
        # is the correct size, this hack fixes that, its not safe for use with swr_convert
        if lib.USING_AVRESAMPLE:
            src_nb_samples += 1000
        
        while True:
            frame = AudioFrame()
            
            # allocate the correct frame size
            frame.alloc_frame(dst_nb_channels, out_sample_fmt, dst_nb_samples)
            frame.fill_frame(dst_nb_samples)

            # Note: swr_convert returns number of samples output per channel,
            # negative value on error
            
            if not flush:
                ret = err_check(lib.swr_convert(self.swr_proxy.ptr,
                                      frame.ptr.extended_data,dst_nb_samples,
                                      self.ptr.extended_data, src_nb_samples))
                
            # Flush any remaining samples out
            else:         
                 ret = err_check(lib.swr_convert(self.swr_proxy.ptr,
                                       frame.ptr.extended_data,dst_nb_samples,
                                       NULL, 0))

            if ret == 0:
                break
            
            # use av_audio_fifo_write command because fifo.write will call frame.resample
            # and loop indefinitely 
            
            err_check(lib.av_audio_fifo_write(fifo.ptr, 
                                          <void **> frame.ptr.extended_data,
                                          ret))
            flush = True
            
        frame = fifo.read()
        
        # copy over pts and time_base
        frame.ptr.pts = self.ptr.pts
        frame.time_base_ = self.time_base_
        
        # close the context (this only does something when using avresample)
        lib.swr_close(self.swr_proxy.ptr)
        
        return frame
        

    property samples:
        """Number of audio samples (per channel) """
        def __get__(self):
            return self.ptr.nb_samples
    
    property rate:
        """Sample rate of the audio data. """
        def __get__(self):
            return self.ptr.sample_rate

            
        
        
