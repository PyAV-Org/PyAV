from cpython.oldbuffer cimport PyBuffer_FromMemory
from cpython cimport array
from libc.stdint cimport int64_t, uint8_t, uint64_t

cimport libav as lib

cimport av.format
from .utils cimport err_check,avrational_to_faction, channel_layout_name,samples_alloc_array_and_samples


cdef class Codec(object):
    
    def __init__(self, av.format.Stream stream):
        
        # Our pointer.
        self.ctx = stream.ptr.codec
        
        # Keep these pointer alive with this reference.
        self.format_ctx = stream.ctx_proxy
        
        if stream.type == 'attachment':
            return
        
        if self.format_ctx.is_input:
            # Find the decoder.
            # We don't need to free this later since it is a static part of the lib.
            self.ptr = lib.avcodec_find_decoder(self.ctx.codec_id)
            if self.ptr == NULL:
                return
            
            # Open the codec.
            try:
                err_check(lib.avcodec_open2(self.ctx, self.ptr, &self.options))
            except:
                # Signal that we don't need to close it.
                self.ptr = NULL
                raise
        else:
            self.ptr = self.ctx.codec
            print "encoder"
            pass
    
    def __dealloc__(self):
        if self.ptr != NULL:
            lib.avcodec_close(self.ctx);
        if self.options != NULL:
            lib.av_dict_free(&self.options)
    
    property name:
        def __get__(self): return bytes(self.ptr.name) if self.ptr else None
    property long_name:
        def __get__(self): return bytes(self.ptr.long_name) if self.ptr else None
        
    property bit_rate:
        def __get__(self): return self.ctx.bit_rate if self.ctx else None
        def __set__(self, int value):
            self.ctx.bit_rate = value
            
    property bit_rate_tolerance:
        def __get__(self): return self.ctx.bit_rate_tolerance if self.ctx else None
        def __set__(self, int value):
            self.ctx.bit_rate_tolerance = value
            
    property time_base:
        def __get__(self): return avrational_to_faction(&self.ctx.time_base) if self.ctx else None
            
    property gop_size:
        def __get__(self): return self.ctx.gop_size if self.ctx else None
        def __set__(self, int value):
            self.ctx.gop_size = value
            
    property pix_fmt:
        def __get__(self):
            if not self.ctx:
                return None
            result = lib.av_get_pix_fmt_name(self.ctx.pix_fmt)
            if result == NULL:
                return None
            return result
        # Note should check if codec supports pix_fmt
        def __set__(self, char* value):
            cdef lib.AVPixelFormat pix_fmt = lib.av_get_pix_fmt(value)
            if pix_fmt == lib.AV_PIX_FMT_NONE:
                raise ValueError("invalid pix_fmt %s" % value)
            self.ctx.pix_fmt = pix_fmt
    
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
            
    property width:
        def __get__(self): return self.ctx.width if self.ctx else None
        def __set__(self, int value):
            self.ctx.width = value
            
    property height:
        def __get__(self): return self.ctx.height if self.ctx else None
        def __set__(self, int value):
            self.ctx.height = value
            
    
    

cdef class Packet(object):
    
    """A packet of encoded data within a :class:`~av.format.Stream`.

    This may, or may not include a complete object within a stream.
    :meth:`decode` must be called to extract encoded data.

    """
    def __init__(self):
        lib.av_init_packet(&self.struct)

    def __dealloc__(self):
        lib.av_free_packet(&self.struct)
    
    def __repr__(self):
        return '<%s.%s of %s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.stream,
            id(self),
        )
    
    def decode(self):
        """Decode the data in this packet.

       yields frame.
       
       Note.
       Some codecs will cause frames to be buffered up in the decoding process. If Packets Data
       is NULL and size is 0 the packet will try and retrieve those frames. Context.demux will 
       yeild a NULL Packet as its last packet.
        """

        if not self.struct.data:
            while True:
                frame = self.stream.decode(self)
                if frame:
                    yield frame
                else:
                    break
        else:
            frame = self.stream.decode(self)
            if frame:
                yield frame
                
    property pts:
        def __get__(self): return self.struct.pts
    property dts:
        def __get__(self): return self.struct.dts
    property size:
        def __get__(self): return self.struct.size
    property duration:
        def __get__(self): return self.struct.duration


cdef class SubtitleProxy(object):
    def __dealloc__(self):
        lib.avsubtitle_free(&self.struct)


cdef class Subtitle(object):
    
    def __init__(self, Packet packet, SubtitleProxy proxy):
        self.packet = packet
        self.proxy = proxy
        cdef int i
        self.rects = tuple(SubtitleRect(self, i) for i in range(self.proxy.struct.num_rects))
    
    def __repr__(self):
        return '<%s.%s of %s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.packet.stream,
            id(self),
        )
    
    property format:
        def __get__(self): return self.proxy.struct.format
    property start_display_time:
        def __get__(self): return self.proxy.struct.start_display_time
    property end_display_time:
        def __get__(self): return self.proxy.struct.end_display_time
    property pts:
        def __get__(self): return self.proxy.struct.pts


cdef class SubtitleRect(object):

    def __init__(self, Subtitle subtitle, int index):
        if index < 0 or index >= subtitle.proxy.struct.num_rects:
            raise ValueError('subtitle rect index out of range')
        self.proxy = subtitle.proxy
        self.ptr = self.proxy.struct.rects[index]
        
        if self.ptr.type == lib.SUBTITLE_NONE:
            self.type = b'none'
        elif self.ptr.type == lib.SUBTITLE_BITMAP:
            self.type = b'bitmap'
        elif self.ptr.type == lib.SUBTITLE_TEXT:
            self.type = b'text'
        elif self.ptr.type == lib.SUBTITLE_ASS:
            self.type = b'ass'
        else:
            raise ValueError('unknown subtitle type %r' % self.ptr.type)
    
    def __repr__(self):
        return '<%s.%s %s %dx%d at %d,%d; at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.type,
            self.width,
            self.height,
            self.x,
            self.y,
            id(self),
        )
    
    property x:
        def __get__(self): return self.ptr.x
    property y:
        def __get__(self): return self.ptr.y
    property width:
        def __get__(self): return self.ptr.w
    property height:
        def __get__(self): return self.ptr.h
    property nb_colors:
        def __get__(self): return self.ptr.nb_colors
    property text:
        def __get__(self): return self.ptr.text
        
    property ass:
        def __get__(self): return self.ptr.ass

    property pict_line_sizes:
        def __get__(self):
            if self.ptr.type != lib.SUBTITLE_BITMAP:
                return ()
            else:
                # return self.ptr.nb_colors
                return tuple(self.ptr.pict.linesize[i] for i in range(4))
    
    property pict_buffers:
        def __get__(self):
            cdef float [:] buffer_
            if self.ptr.type != lib.SUBTITLE_BITMAP:
                return ()
            else:
                return tuple(
                    PyBuffer_FromMemory(self.ptr.pict.data[i], self.width * self.height)
                    if width else None
                    for i, width in enumerate(self.pict_line_sizes)
                )

cdef class SwsContextProxy(object):
    def __dealloc__(self):
        lib.sws_freeContext(self.ptr)

cdef class SwrContextProxy(object):
    def __dealloc__(self):
        lib.swr_free(&self.ptr)
                         
cdef class Frame(object):

    """Frame Base Class"""
        
    def __dealloc__(self):
        # These are all NULL safe.
        lib.avcodec_free_frame(&self.ptr)
        
    property pts:
        """Presentation time stamp of this frame."""
        def __get__(self):
            return self.ptr.pts

cdef class VideoFrame(Frame):

    """A frame of video."""

    def __dealloc__(self):
        # These are all NULL safe.
        lib.av_freep(&self.buffer_)
    
    def __repr__(self):
        return '<%s.%s %dx%d at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.width,
            self.height,
            id(self),
        )
        
    def to_rgba(self):
        
        """ Returns a new VideoFrame object that is converted from what every pix_fmt is 
        currently is to rgba pix_fmt
        """
        
        return self.reformat(self.width,self.height, "rgba")
        
    cpdef reformat(self, int width, int height, char* pix_fmt):
    
        """ Returns a new VideoFrame object scaled to width and height and converted to 
        specified pix_fmt
        """
        
        cdef lib.AVPixelFormat dst_pix_fmt = lib.av_get_pix_fmt(pix_fmt)
        if dst_pix_fmt == lib.AV_PIX_FMT_NONE:
            raise ValueError("invalid destination pix_fmt %s" % pix_fmt)
        
        if self.ptr.format < 0:
            raise ValueError("invalid source pix_fmt")
        
        cdef lib.AVPixelFormat src_pix_fmt = <lib.AVPixelFormat> self.ptr.format
        
        # If VideoFrame doesn't have a SwsContextProxy create one
        if not self.sws_proxy:
            self.sws_proxy = SwsContextProxy()
        
        # Try and reuse existing SwsContextProxy
        # VideoStream.decode will copy its SwsContextProxy to VideoFrame
        # So all Video frames from the same VideoStream should have the same one
        
        self.sws_proxy.ptr = lib.sws_getCachedContext(
            self.sws_proxy.ptr,
            self.ptr.width,
            self.ptr.height,
            src_pix_fmt,
            width,
            height,
            dst_pix_fmt,
            lib.SWS_BILINEAR,
            NULL,
            NULL,
            NULL
        )
        
        # Create a new VideoFrame
        
        cdef VideoFrame frame = VideoFrame()
        frame.ptr= lib.avcodec_alloc_frame()
        lib.avcodec_get_frame_defaults(frame.ptr)
        
        # Calculate buffer size needed for new image
        frame.buffer_size = lib.avpicture_get_size(
            dst_pix_fmt,
            width,
            height,
            )
        
        # Allocate the new Buffer
        frame.buffer_ = <uint8_t *>lib.av_malloc(frame.buffer_size * sizeof(uint8_t))
        
        if not frame.buffer_:
            raise MemoryError("Cannot allocate reformatted VideoFrame buffer")
        
        lib.avpicture_fill(
                <lib.AVPicture *>frame.ptr,
                frame.buffer_,
                dst_pix_fmt,
                width,
                height
        )
        
        # Finally Scale the image
        lib.sws_scale(
            self.sws_proxy.ptr,
            self.ptr.data,
            self.ptr.linesize,
            0, # slice Y
            self.ptr.height,
            frame.ptr.data,
            frame.ptr.linesize,
        )
        
        # Set new frame properties
        frame.ptr.width = width
        frame.ptr.height = height
        frame.ptr.format = dst_pix_fmt
        
        frame.frame_index = self.frame_index
        
        # Copy over pts
        frame.ptr.pts = self.ptr.pts
        
        return frame
        
    property width:
        """Width of the image, in pixels."""
        def __get__(self): return self.ptr.width

    property height:
        """Height of the image, in pixels."""
        def __get__(self): return self.ptr.height
    
    property pix_fmt:
        """Pixel format of the image."""
        def __get__(self):
            result = lib.av_get_pix_fmt_name(<lib.AVPixelFormat > self.ptr.format)
            if result == NULL:
                return None
            return result
        
    property key_frame:
        """return 1 if frame is a key frame"""
        def __get__(self): return self.ptr.key_frame

    # Legacy buffer support.
    # See: http://docs.python.org/2/c-api/typeobj.html#PyBufferProcs

    def __getsegcount__(self, Py_ssize_t *len_out):
        if len_out != NULL:
            len_out[0] = <Py_ssize_t> self.buffer_size
        return 1

    def __getreadbuffer__(self, Py_ssize_t index, void **data):
        if index:
            raise RuntimeError("accessing non-existent buffer segment")
        data[0] = <void*> self.ptr.data[0]
        return <Py_ssize_t> self.buffer_size


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
        
    cdef alloc_frame(self, int channels, lib.AVSampleFormat sample_fmt, int nb_samples):
     
        if self.ptr:
            if self.buffer_:
                lib.av_freep(&self.buffer_[0])
            lib.av_freep(&self.buffer_)
            lib.avcodec_free_frame(&self.ptr)
        cdef int ret
        cdef int linesize
        
        self.ptr= lib.avcodec_alloc_frame()
        lib.avcodec_get_frame_defaults(self.ptr)
        
        ret = samples_alloc_array_and_samples(&self.buffer_, 
                                              &linesize,
                                              channels,
                                              nb_samples,
                                              sample_fmt,0)
        if ret < 0:
            raise MemoryError("error samples_alloc_array_and_samples: %s" % lib.av_err2str(ret))

        self.ptr.channels = channels
        self.ptr.format = sample_fmt
        
        self.ptr.nb_samples = nb_samples
        
        
    cdef fill_frame(self, int nb_samples):
        if not self.ptr:
            raise Exception("Frame Not allocated")

        samples_size = lib.av_samples_get_buffer_size(NULL,
                                                       self.ptr.channels,
                                                       self.ptr.nb_samples,
                                                       <lib.AVSampleFormat>self.ptr.format,0)
        
        self.ptr.nb_samples = nb_samples
        ret =lib.avcodec_fill_audio_frame(self.ptr, 
                                             self.ptr.channels, 
                                             <lib.AVSampleFormat> self.ptr.format,
                                             self.buffer_[0],
                                             samples_size, 0)

        if ret < 0:
            raise Exception("avcodec_fill_audio_frame failed")
        
        self.buffer_size = samples_size
    
    def resample(self, char* channel_layout, char* sample_fmt, int out_sample_rate):
        #print channel_layout, sample_fmt, sample_rate
        cdef uint64_t out_ch_layout = lib.av_get_channel_layout(channel_layout)
        if out_ch_layout == 0:
            raise ValueError("invalid channel layout %s" % channel_layout)
            
        cdef lib.AVSampleFormat out_sample_fmt = lib.av_get_sample_fmt(sample_fmt)
        if out_sample_fmt == lib.AV_SAMPLE_FMT_NONE:
            raise ValueError("invalid sample_fmt %s" % sample_fmt)
        
        if not self.swr_proxy:
            self.swr_proxy = SwrContextProxy()
        
        # setup SwrContext
        self.swr_proxy.ptr = lib.swr_alloc_set_opts(
            self.swr_proxy.ptr,
            out_ch_layout,
            out_sample_fmt,
            out_sample_rate,
            self.ptr.channel_layout,
            <lib.AVSampleFormat > self.ptr.format,
            self.ptr.sample_rate,
            0,
            NULL
        )
        
        if lib.swr_init(self.swr_proxy.ptr) < 0:
            raise Exception("Failed to initialize the resampling context")

        # helper names, just so I remember what they are       
        cdef int src_nb_samples = self.ptr.nb_samples
        cdef int src_rate = self.ptr.sample_rate
        
        # compute the number of converted samples
        cdef int dst_nb_samples = lib.av_rescale_rnd(src_nb_samples,
                                                 out_sample_rate, #dst sample rate
                                                 src_rate, # src sample rate
                                                 lib.AV_ROUND_UP) + 50

        cdef int dst_nb_channels = lib.av_get_channel_layout_nb_channels(out_ch_layout)
        cdef AudioFrame frame
        
        flush = False
        
        while True:
            frame = AudioFrame()
            
            # allocate the correct frame size
            frame.alloc_frame( dst_nb_channels, out_sample_fmt, dst_nb_samples)

            # Note: swr_convert returns number of samples output per channel,
            # negative value on error
            
            if not flush:
                ret = lib.swr_convert(self.swr_proxy.ptr,
                                      frame.buffer_,dst_nb_samples,
                                      self.ptr.extended_data, src_nb_samples)
            else:         
                 ret =lib.swr_convert(self.swr_proxy.ptr,
                                       frame.buffer_,dst_nb_samples,
                                       NULL, 0)
    
            if ret <0:
                raise Exception("error swr_convert: %s" % lib.av_err2str(ret))
            
            if ret == 0:
                break
        
            dst_nb_samples = ret

            frame.fill_frame(dst_nb_samples)

            frame.ptr.sample_rate = out_sample_rate
            frame.ptr.channel_layout = out_ch_layout
            frame.frame_index = self.frame_index

            # not sure what to do with the pts yet
            frame.ptr.pts = lib.AV_NOPTS_VALUE
            
            yield frame
            flush = True
        

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
        def __get__(self): return self.ptr.channels
        
    property channel_layout:
        """Audio channel layout"""
        def __get__(self):
            result = channel_layout_name(self.ptr.channels, self.ptr.channel_layout)
            if result == NULL:
                return None
            return result
            
        
cdef class AudioFifo:

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
     
    def __init__(self, char* channel_layout,char* sample_fmt, 
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

        
    def write(self, AudioFrame frame):
        cdef AudioFrame resampled_frame
        for resampled_frame in frame.resample(self.channel_layout, self.sample_fmt, self.sample_rate):
            
            ret = lib.av_audio_fifo_write(self.ptr, 
                                          <void **> resampled_frame.ptr.extended_data,
                                          resampled_frame.samples)
            if ret != resampled_frame.samples:
                raise Exception("error writing to AudioFifo")
            
    def read(self, int nb_samples=-1):
        
        if nb_samples < 1 or nb_samples > self.samples:
            nb_samples = self.samples
            
        if not nb_samples:
            raise Exception("Fifo is Empty")
            
        
        cdef int ret
        cdef int linesize
        cdef int sample_size
        cdef AudioFrame frame = AudioFrame()
        
        frame.alloc_frame(self.channels_,self.sample_fmt_,nb_samples)
        
        if ret <0:
            raise Exception("error samples_alloc_array_and_samples: %s" % lib.av_err2str(ret))
        
        ret = lib.av_audio_fifo_read(self.ptr,
                                     <void **> frame.buffer_,
                                     nb_samples)
        
        if ret != nb_samples:
            raise Exception("Fifo read Error")
        
        frame.fill_frame(nb_samples)
        
        frame.ptr.sample_rate = self.sample_rate_
        frame.ptr.channel_layout = self.channel_layout_
        
        
        return frame
    
    def get_frames(self, int nb_samples):
        print "asking for", nb_samples, "have", self.samples
        while True:
            
            if self.samples < nb_samples:
                break

            yield self.read(nb_samples)
        
        
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
        
        

