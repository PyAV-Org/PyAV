from cpython.oldbuffer cimport PyBuffer_FromMemory
from cpython cimport array

cimport libav as lib

cimport av.format
from .utils cimport err_check,avrational_to_faction


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
        def __set__(self, char* value):
            cdef lib.AVPixelFormat pix_fmt = lib.av_get_pix_fmt(value)
            if pix_fmt == lib.AV_PIX_FMT_NONE:
                raise ValueError("invalid pix_fmt %s" % value)
            self.ctx.pix_fmt = pix_fmt
            
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
cdef class Frame(object):

    """Frame Base Class"""
    
    def __init__(self, Packet packet):
        self.packet = packet
        
    def __dealloc__(self):
        # These are all NULL safe.
        lib.av_free(self.ptr)

cdef class VideoFrame(Frame):

    """A frame of video."""

    def __dealloc__(self):
        
        # These are all NULL safe.
        lib.av_free(self.ptr)
        lib.av_free(self.raw_ptr)
        lib.av_free(self.rgb_ptr)
        lib.av_free(self.buffer_)
    
    def __repr__(self):
        return '<%s.%s %dx%d at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.width,
            self.height,
            id(self),
        )
    
    property pts:
        """Presentation time stamp of this frame."""
        def __get__(self):
            return lib.av_frame_get_best_effort_timestamp(self.raw_ptr)
        
    property width:
        """Width of the image, in pixels."""
        def __get__(self): return self.raw_ptr.width

    property height:
        """Height of the image, in pixels."""
        def __get__(self): return self.raw_ptr.height
        
    property key_frame:
        """return 1 if frame is a key frame"""
        def __get__(self): return self.raw_ptr.key_frame

    # Legacy buffer support.
    # See: http://docs.python.org/2/c-api/typeobj.html#PyBufferProcs

    def __getsegcount__(self, Py_ssize_t *len_out):
        if len_out != NULL:
            len_out[0] = <Py_ssize_t> self.packet.stream.buffer_size
        return 1

    def __getreadbuffer__(self, Py_ssize_t index, void **data):
        if index:
            raise RuntimeError("accessing non-existent buffer segment")
        data[0] = <void*> self.rgb_ptr.data[0]
        #print "buff_size",self.packet.stream.buffer_size, lib.av_get_pix_fmt_name(<lib.AVPixelFormat>self.raw_ptr.format),

        return <Py_ssize_t> self.packet.stream.buffer_size


cdef class AudioFrame(Frame):

    """A frame of audio."""

    pass

