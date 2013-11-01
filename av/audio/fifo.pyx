from av.utils cimport err_check, channel_layout_name

        
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
                                     <void **>frame._buffer,
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
        
