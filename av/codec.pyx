from cpython.oldbuffer cimport PyBuffer_FromMemory
from cpython cimport array

cimport libav as lib

cimport av.format
from .utils cimport err_check

cdef class Codec(object):
    
    def __init__(self, av.format.Stream stream):
        
        
        # Our pointer.
        self.ctx = stream.ptr.codec
        
        # Keep these pointer alive with this reference.
        self.format_ctx = stream.ctx_proxy
        
        if stream.type == 'attachment':
            return
        
        # We don't need to free this later since it is a static part of the lib.
        self.ptr = lib.avcodec_find_decoder(self.ctx.codec_id)
        if self.ptr == NULL:
            return
        
        try:
            err_check(lib.avcodec_open2(self.ctx, self.ptr, &self.options))
        except:
            # Signal that we don't need to close it.
            self.ptr = NULL
            raise
    
    def __dealloc__(self):
        if self.ptr != NULL:
            lib.avcodec_close(self.ctx);
        if self.options != NULL:
            lib.av_dict_free(&self.options)
    
    property name:
        def __get__(self): return bytes(self.ptr.name) if self.ptr else None
    property long_name:
        def __get__(self): return bytes(self.ptr.long_name) if self.ptr else None
    

cdef class Packet(object):
    
    def __dealloc__(self):
        lib.av_free_packet(&self.struct)
    
    def __repr__(self):
        return '<%s.%s of %s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.stream,
            id(self),
        )
    
    cpdef decode(self):
        return self.stream.decode(self)
    
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
    
    def __init__(self, av.format.Stream stream, SubtitleProxy proxy):
        self.stream = stream
        self.proxy = proxy
        cdef int i
        self.rects = tuple(SubtitleRect(self, i) for i in range(self.proxy.struct.num_rects))
    
    def __repr__(self):
        return '<%s.%s of %s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.stream,
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

    def __init__(self, av.format.Stream stream):
        self.stream = stream
    
    def __dealloc__(self):
        # These are all NULL safe.
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
        def __get__(self):
            if self.raw_ptr.pts != lib.AV_NOPTS_VALUE:
                return self.raw_ptr.pts
            else:
                return self.raw_ptr.pkt_pts
    
    property width:
        def __get__(self): return self.stream.codec.ctx.width
    property height:
        def __get__(self): return self.stream.codec.ctx.height

    # Legacy buffer support.
    # See: http://docs.python.org/2/c-api/typeobj.html#PyBufferProcs

    def __getsegcount__(self, Py_ssize_t *len_out):
        if len_out != NULL:
            len_out[0] = <Py_ssize_t> self.stream.buffer_size
        return 1

    def __getreadbuffer__(self, Py_ssize_t index, void **data):
        if index:
            raise RuntimeError("accessing non-existent buffer segment")
        data[0] = <void*> self.rgb_ptr.data[0]
        return <Py_ssize_t> self.stream.buffer_size











