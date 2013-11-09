cimport libav as lib


cdef class AudioCodec(Codec):

    property frame_size:
        """Number of samples per channel in an audio frame."""
        def __get__(self): return self.ctx.frame_size
        
    property sample_rate:
        """samples per second """
        def __get__(self): return self.ctx.sample_rate
        def __set__(self, int value): self.ctx.sample_rate = value

    property sample_fmt:
        """Audio sample format"""
        def __get__(self):
            if not self.ctx:
                return None
            result = lib.av_get_sample_fmt_name(self.ctx.sample_fmt)
            if result == NULL:
                return None
            return result
        # Note should check if codec supports sample_fmt
        def __set__(self, char* value):
            cdef lib.AVSampleFormat sample_fmt = lib.av_get_sample_fmt(value)
            if sample_fmt == lib.AV_SAMPLE_FMT_NONE:
                raise ValueError("invalid sample_fmt %s" % value)
            self.ctx.sample_fmt = sample_fmt

    
    '''
    property channels:
        """Number of audio channels"""
        def __get__(self):
            return self.ctx.channels
        def __set__(self, int value):
            
            self.ctx.channels = value
            # set channel layout to default layout for that many channels
            self.ctx.channel_layout = lib.av_get_default_channel_layout(value)
            
    property channel_layout:
        """Audio channel layout"""
        def __get__(self):
            result = channel_layout_name(self.ctx.channels, self.ctx.channel_layout)
            if result == NULL:
                return None
            return result
        
        def __set__(self, char* value):
            
            cdef uint64_t channel_layout = lib.av_get_channel_layout(value)
            
            if channel_layout == 0:
                raise ValueError("invalid channel layout %s" % value)
            
            self.ctx.channel_layout = channel_layout
            self.ctx.channels = lib.av_get_channel_layout_nb_channels(channel_layout)
    '''