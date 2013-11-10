from libc.stdint cimport uint64_t

cimport libav as lib

from av.audio.fifo cimport AudioFifo
from av.utils cimport err_check


cdef class AudioResampler(object):

    def __dealloc__(self):
        lib.swr_free(&self.ptr)


    cpdef resample(self, AudioFrame src):
        
        # TODO: set these
        cdef bytes channel_layout = b'stereo'
        cdef bytes sample_fmt = b's16'
        cdef int out_sample_rate = 48000

        # Check params
        cdef uint64_t out_ch_layout = lib.av_get_channel_layout(channel_layout)
        if out_ch_layout == 0:
            raise ValueError("invalid channel layout %s" % channel_layout)
            
        cdef lib.AVSampleFormat out_sample_fmt = lib.av_get_sample_fmt(sample_fmt)
        if out_sample_fmt == lib.AV_SAMPLE_FMT_NONE:
            raise ValueError("invalid sample_fmt %s" % sample_fmt)
        
        # if not self.swr_proxy:
        #     self.swr_proxy = SwrContextProxy()
        
        cdef int dst_nb_channels = lib.av_get_channel_layout_nb_channels(out_ch_layout)
            
        #print "source =", self.sample_rate, self.channel_layout,self.ptr.channel_layout, self.channels, self.sample_fmt,self.ptr.format
        #print "dest   =", out_sample_rate, channel_layout,out_ch_layout, dst_nb_channels, sample_fmt, out_sample_fmt

        if not self.ptr:
            self.ptr = lib.swr_alloc()
        
        err_check(lib.av_opt_set_int(self.ptr, "in_channel_layout" , src.ptr.channel_layout,0))
        err_check(lib.av_opt_set_int(self.ptr, "out_channel_layout" ,out_ch_layout,0))
        
        err_check(lib.av_opt_set_int(self.ptr, 'in_sample_rate', src.ptr.sample_rate, 0))
        err_check(lib.av_opt_set_int(self.ptr, 'out_sample_rate', out_sample_rate, 0))
        
        err_check(lib.av_opt_set_int(self.ptr, 'in_sample_fmt', src.ptr.format, 0))
        err_check(lib.av_opt_set_int(self.ptr, 'out_sample_fmt', <int>out_sample_fmt, 0))
        
        err_check(lib.swr_init(self.ptr))
        
        # helper names, just so I remember what they are       
        cdef int src_nb_samples = src.ptr.nb_samples
        cdef int src_rate = src.ptr.sample_rate
        
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
                ret = err_check(lib.swr_convert(self.ptr,
                                      frame.ptr.extended_data,dst_nb_samples,
                                      src.ptr.extended_data, src_nb_samples))
                
            # Flush any remaining samples out
            else:         
                 ret = err_check(lib.swr_convert(self.ptr,
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
        frame.ptr.pts = src.ptr.pts
        frame.time_base_ = src.time_base_
        
        # close the context (this only does something when using avresample)
        lib.swr_close(self.ptr)
        
        return frame
        

