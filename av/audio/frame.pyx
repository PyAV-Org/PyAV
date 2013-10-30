from av.utils cimport err_check, samples_alloc_array_and_samples, channel_layout_name


cdef class SwrContextProxy(object):
    def __dealloc__(self):
        lib.swr_free(&self.ptr)


cdef class AudioFrame(Frame):

    """A frame of audio."""
    
    def __dealloc__(self):
        # These are all NULL safe.
        if self.buffer_:
            lib.av_freep(&self.buffer_[0])
        lib.av_freep(&self.buffer_)
    
    def __repr__(self):
        return '<%s.%s nb_samples:%d %dhz %s %s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.samples,
            self.sample_rate,
            self.channel_layout,
            self.sample_fmt,
            id(self),
        )
        
    def __init__(self, *args):
        super(AudioFrame, self).__init__(*args)
        self.align = 1
        
    cdef alloc_frame(self, int channels, lib.AVSampleFormat sample_fmt, int nb_samples):
     
        if self.ptr:
            return

        cdef int ret
        cdef int linesize
        
        self.ptr = lib.avcodec_alloc_frame()
        lib.avcodec_get_frame_defaults(self.ptr)
        
        err_check(samples_alloc_array_and_samples(
            &self.buffer_, 
            &linesize,
            channels,
            nb_samples,
            sample_fmt,
            self.align,
        ))

        # TODO: Set channel layout.
        self.ptr.format = <int > sample_fmt
        self.ptr.nb_samples = nb_samples
                
        
    cdef fill_frame(self, int nb_samples):
        if not self.ptr:
            raise MemoryError("Frame Not allocated")
        
        self.ptr.nb_samples = nb_samples

        samples_size = lib.av_samples_get_buffer_size(NULL,
                                                       self.channels,
                                                       self.ptr.nb_samples,
                                                       <lib.AVSampleFormat>self.ptr.format,self.align)
        
        err_check(lib.avcodec_fill_audio_frame(self.ptr, 
                                             self.channels, 
                                             <lib.AVSampleFormat> self.ptr.format,
                                             self.buffer_[0],
                                             samples_size, self.align))
        
        self.buffer_size = samples_size
        
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
    
    property sample_rate:
        """Sample rate of the audio data. """
        def __get__(self):
            return self.ptr.sample_rate

    property sample_fmt:
        """Audio Sample Format"""
        def __get__(self):
            result = lib.av_get_sample_fmt_name(<lib.AVSampleFormat > self.ptr.format)
            if result == NULL:
                return None
            return result
        
    property channels:
        """Number of audio channels"""
        # It would be great to just look at self.ptr.channels, but it doesn't
        # exist in Libav! So, we must be drastic.
        def __get__(self): return lib.av_get_channel_layout_nb_channels(self.ptr.channel_layout)
        
    property channel_layout:
        """Audio channel layout"""
        def __get__(self):
            result = channel_layout_name(self.channels, self.ptr.channel_layout)
            if result == NULL:
                return None
            return result
            
        
cdef class AudioFifo:

    """A simple Audio FIFO (First In First Out) Buffer. Accept any AudioFrame. Will automatically convert it 
    to match the channel_layout, sample_fmt and sample_rate specified upon initialization. 
    """

    def __dealloc__(self):
        lib.av_audio_fifo_free(self.ptr)
        
    def __repr__(self):
        return '<%s.%s nb_samples:%s %dhz %s %s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.samples,
            self.sample_rate,
            self.channel_layout,
            self.sample_fmt,
            id(self),
        )
     
    def __init__(self, bytes channel_layout,bytes sample_fmt, 
                            int sample_rate, int nb_samples):
        
        cdef uint64_t ch_layout = lib.av_get_channel_layout(channel_layout)
        if ch_layout == 0:
            raise ValueError("invalid channel layout %s" % channel_layout)
            
        cdef lib.AVSampleFormat fmt = lib.av_get_sample_fmt(sample_fmt)
        if fmt == lib.AV_SAMPLE_FMT_NONE:
            raise ValueError("invalid sample_fmt %s" % sample_fmt)
        
        cdef int channels = lib.av_get_channel_layout_nb_channels(ch_layout)
        
        self.ptr = lib.av_audio_fifo_alloc(fmt, channels, nb_samples)
        if not self.ptr:
            raise MemoryError("Unable to allocate AVAudioFifo")
        
        self.sample_fmt_ = fmt
        self.sample_rate_ = sample_rate
        self.channel_layout_ = ch_layout
        self.channels_ = channels
        self.add_silence = False
        
        self.last_pts = lib.AV_NOPTS_VALUE
        self.pts_offset = 0
        
        self.time_base_.num = 1
        self.time_base_.den = self.sample_rate_
        
    cpdef write(self, AudioFrame frame):
    
        """Write a Frame to the Audio FIFO Buffer. If the AudioFrame has a valid pts the FIFO will store it.
        """
        
        cdef int ret
        cdef AudioFrame resampled_frame = frame.resample(self.channel_layout, self.sample_fmt, self.sample_rate)
        
        if resampled_frame.ptr.pts != lib.AV_NOPTS_VALUE:
            
            self.last_pts = lib.av_rescale_q(resampled_frame.ptr.pts, 
                                             resampled_frame.time_base_, 
                                             self.time_base_)
            self.pts_offset = self.samples
            
        err_check(lib.av_audio_fifo_write(self.ptr, 
                                      <void **> resampled_frame.ptr.extended_data,
                                      resampled_frame.samples))

    cpdef read(self, int nb_samples=-1):
    
        """Read nb_samples from the Audio FIFO. returns a AudioFrame. If nb_samples is -1, will return a AudioFrame
        with all the samples currently in the FIFO. If a frame was supplied with a valid pts the Audio frame returned
        will contain a pts adjusted for the current read. The time_base of the pts will always be in 1/sample_rate time_base.
        """
        
        if nb_samples < 1:
            nb_samples = self.samples
            
        if not self.add_silence and nb_samples > self.samples:
            nb_samples = self.samples
            
        if not nb_samples:
            raise EOFError("Fifo is Empty")

        cdef int ret
        cdef int linesize
        cdef int sample_size
        cdef AudioFrame frame = AudioFrame()
        
        frame.alloc_frame(self.channels_,self.sample_fmt_,nb_samples)
        
        ret = lib.av_audio_fifo_read(self.ptr,
                                     <void **> frame.buffer_,
                                     nb_samples)

        frame.fill_frame(nb_samples)
        
        if self.add_silence and ret < nb_samples:
            frame.set_silence(ret, nb_samples - ret)
        
        frame.ptr.sample_rate = self.sample_rate_
        frame.ptr.channel_layout = self.channel_layout_
        
        if self.last_pts != lib.AV_NOPTS_VALUE:
            
            frame.time_base_ = self.time_base_
            frame.ptr.pts = self.last_pts - self.pts_offset
            
            # move the offset
            self.pts_offset -= nb_samples
        
        return frame
        
    property samples:
        """Number of audio samples (per channel) """
        def __get__(self):
            return lib.av_audio_fifo_size(self.ptr)
    
    property sample_rate:
        """Sample rate of the audio data. """
        def __get__(self):
            return self.sample_rate_

    property sample_fmt:
        """Audio Sample Format"""
        def __get__(self):
            result = lib.av_get_sample_fmt_name(self.sample_fmt_)
            if result == NULL:
                return None
            return result
        
    property channels:
        """Number of audio channels"""
        def __get__(self): return self.channels_
        
    property channel_layout:
        """Audio channel layout"""
        def __get__(self):
            result = channel_layout_name(self.channels_, self.channel_layout_)
            if result == NULL:
                return None
            return result
        
