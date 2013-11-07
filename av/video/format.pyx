cdef class Descriptor(object):

    def __cinit__(self, bytes name):
        self.pix_fmt = lib.av_get_pix_fmt(name)
        if self.pix_fmt < 0:
            raise ValueError('not a pixel format: %r' % name)
        self.ptr = lib.av_pix_fmt_desc_get(self.pix_fmt)
        self.components = tuple(ComponentDescriptor(self, i) for i in range(self.ptr.nb_components))

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

    def chroma_width(self, unsigned int luma_width):
        return luma_width >> self.ptr.log2_chroma_w

    def chroma_height(self, unsigned int luma_height):
        return luma_height >> self.ptr.log2_chroma_h



cdef class ComponentDescriptor(object):

    def __cinit__(self, Descriptor format, size_t index):
        self.format = format
        self.ptr = &format.ptr.comp[index]

    property plane:
        def __get__(self):
            return self.ptr.plane

    property bits:
        def __get__(self):
            return self.ptr.depth_minus1 + 1

