cdef class VideoFormat(object):

    def __cinit__(self, bytes name, unsigned int width=0, unsigned int height=0):
        self.pix_fmt = lib.av_get_pix_fmt(name)
        if self.pix_fmt < 0:
            raise ValueError('not a pixel format: %r' % name)
        self.ptr = lib.av_pix_fmt_desc_get(self.pix_fmt)
        self.width = width
        self.height = height
        self.components = tuple(VideoFormatComponent(self, i) for i in range(self.ptr.nb_components))

    property name:
        def __get__(self):
            return self.ptr.name

    property is_big_endian:
        def __get__(self): return bool(self.ptr.flags & lib.PIX_FMT_BE)

    property has_palette:
        def __get__(self): return bool(self.ptr.flags & lib.PIX_FMT_PAL)

    property is_bit_stream:
        def __get__(self): return bool(self.ptr.flags & lib.PIX_FMT_BITSTREAM)

    # Skipping PIX_FMT_HWACCEL

    property is_planar:
        def __get__(self): return bool(self.ptr.flags & lib.PIX_FMT_PLANAR)

    property is_rgb:
        def __get__(self): return bool(self.ptr.flags & lib.PIX_FMT_RGB)

    cpdef chroma_width(self, unsigned int luma_width=0):
        luma_width = luma_width or self.width
        return luma_width >> self.ptr.log2_chroma_w if luma_width else 0

    cpdef chroma_height(self, unsigned int luma_height=0):
        luma_height = luma_height or self.height
        return luma_height >> self.ptr.log2_chroma_h if luma_height else 0



cdef class VideoFormatComponent(object):

    def __cinit__(self, VideoFormat format, size_t index):
        self.format = format
        self.index = index
        self.ptr = &format.ptr.comp[index]

    property plane:
        def __get__(self):
            return self.ptr.plane

    property bits:
        def __get__(self):
            return self.ptr.depth_minus1 + 1

    property is_chroma:
        def __get__(self):
            return (self.index == 1 or self.index == 2) and (self.format.ptr.log2_chroma_w or self.format.ptr.log2_chroma_h)

    property width:
        def __get__(self):
            return self.format.chroma_width() if self.is_chroma else self.format.width

    property height:
        def __get__(self):
            return self.format.chroma_height() if self.is_chroma else self.format.height


