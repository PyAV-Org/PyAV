from libc.stdint cimport uint64_t

from av.audio.fifo cimport AudioFifo
from av.utils cimport err_check, samples_alloc_array_and_samples, channel_layout_name


cdef class AudioFrame(Frame):

    """A frame of audio."""
    
    def __dealloc__(self):
        if self._buffer:
            lib.av_freep(&self._buffer[0])
        lib.av_freep(&self._buffer)
    
    def __repr__(self):
        return '<%s.%s %d samples at %dHz, %s, %s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.samples,
            self.sample_rate,
            self.layout or 'no layout',
            self.format or 'no format',
            id(self),
        )
        
    def __cinit__(self, *args):
        self.align = 1
        
    cdef alloc_frame(self, int channels, lib.AVSampleFormat format, int samples):
     
        if self._buffer:
            return

        cdef int ret
        cdef int linesize
        
        print 'A', self.channels
        err_check(samples_alloc_array_and_samples(
            &self._buffer, 
            &linesize,
            channels,
            samples,
            format,
            self.align,
        ))
        print 'B', self.channels

        # TODO: Set channel layout.
        self.ptr.format = <int>format
        self.ptr.nb_samples = samples
                
        
    cdef fill_frame(self, int samples):

        if not self.ptr:
            raise MemoryError("Frame Not allocated")
        
        self.ptr.nb_samples = samples

        print 'fill channels', self.channels
        samples_size = lib.av_samples_get_buffer_size(
            NULL,
            self.channels,
            self.ptr.nb_samples,
            <lib.AVSampleFormat>self.ptr.format,
            self.align
        )
        print 'buffer size', samples_size
        
        err_check(lib.avcodec_fill_audio_frame(
            self.ptr, 
            self.channels, 
            <lib.AVSampleFormat> self.ptr.format,
            self._buffer[0],
            samples_size,
            self.align
        ))
        
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
            
        print "source =", self.sample_rate, self.layout, self.ptr.channel_layout, self.channels, self.format, self.ptr.format
        print "dest   =", out_sample_rate, channel_layout, out_ch_layout, dst_nb_channels, sample_fmt, out_sample_fmt

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
        """Sample rate of the audio data. Usually 44100, 48000 or 96000."""
        def __get__(self):
            return self.ptr.sample_rate

    property format:
        """Audio Sample Format"""
        def __get__(self):
            result = lib.av_get_sample_fmt_name(<lib.AVSampleFormat>self.ptr.format)
            if result == NULL:
                return None
            return result
        
    property channels:
        """Number of audio channels"""
        # It would be great to just look at self.ptr.channels, but it doesn't
        # exist in Libav! So, we must be drastic.
        def __get__(self):
            return lib.av_get_channel_layout_nb_channels(self.ptr.channel_layout)
        
    property layout:
        """Audio channel layout"""
        def __get__(self):
            result = channel_layout_name(self.channels, self.ptr.channel_layout)
            if result == NULL:
                return None
            return result

    # Legacy buffer support. For `buffer`.
    # See: http://docs.python.org/2/c-api/typeobj.html#PyBufferProcs

    def __getsegcount__(self, Py_ssize_t *len_out):
        if len_out != NULL:
            len_out[0] = <Py_ssize_t>self.buffer_size
        return 1

    def __getreadbuffer__(self, Py_ssize_t index, void **data):
        if index:
            raise RuntimeError("accessing non-existent buffer segment")
        data[0] = <void*>self.ptr.data[0]
        return <Py_ssize_t>self.buffer_size
    
