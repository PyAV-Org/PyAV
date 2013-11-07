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
        """Canonical name of the pixel format."""
        def __get__(self):
            return self.ptr.name

    property is_big_endian:
        """Pixel format is big-endian."""
        def __get__(self): return bool(self.ptr.flags & lib.PIX_FMT_BE)

    property has_palette:
        """Pixel format has a palette in data[1], values are indexes in this palette."""
        def __get__(self): return bool(self.ptr.flags & lib.PIX_FMT_PAL)

    property is_bit_stream:
        """All values of a component are bit-wise packed end to end."""
        def __get__(self): return bool(self.ptr.flags & lib.PIX_FMT_BITSTREAM)

    # Skipping PIX_FMT_HWACCEL
    # """Pixel format is an HW accelerated format."""

    property is_planar:
        """At least one pixel component is not in the first data plane."""
        def __get__(self): return bool(self.ptr.flags & lib.PIX_FMT_PLANAR)

    property is_rgb:
        """The pixel format contains RGB-like data (as opposed to YUV/grayscale)."""
        def __get__(self): return bool(self.ptr.flags & lib.PIX_FMT_RGB)

    cpdef chroma_width(self, int luma_width=0):
        """chroma_width(luma_width=0)

        Width of a chroma plane relative to a luma plane.

        :param int luma_width: Width of the luma plane; defaults to ``self.width``.

        """
        luma_width = luma_width or self.width
        return -((-luma_width) >> self.ptr.log2_chroma_w) if luma_width else 0

    cpdef chroma_height(self, int luma_height=0):
        """chroma_height(luma_height=0)

        Height of a chroma plane relative to a luma plane.

        :param int luma_height: Height of the luma plane; defaults to ``self.height``.

        """
        luma_height = luma_height or self.height
        return -((-luma_height) >> self.ptr.log2_chroma_h) if luma_height else 0



cdef class VideoFormatComponent(object):

    def __cinit__(self, VideoFormat format, size_t index):
        self.format = format
        self.index = index
        self.ptr = &format.ptr.comp[index]

    property plane:
        """The index of the plane which contains this component."""
        def __get__(self):
            return self.ptr.plane

    property bits:
        """Number of bits in the component."""
        def __get__(self):
            return self.ptr.depth_minus1 + 1

    property is_alpha:
        """Is this component an alpha channel?"""
        def __get__(self):
            return ((self.index == 1 and self.format.ptr.nb_components == 2) or 
                    (self.index == 3 and self.format.ptr.nb_components == 4))

    property is_luma:
        """Is this compoment a luma channel?"""
        def __get__(self):
            return self.index == 0 and (
                self.format.ptr.nb_components == 1 or
                self.format.ptr.nb_components == 2 or
                not self.format.is_rgb
            )

    property is_chroma:
        """Is this component a chroma channel?"""
        def __get__(self):
            return (self.index == 1 or self.index == 2) and (self.format.ptr.log2_chroma_w or self.format.ptr.log2_chroma_h)

    property width:
        """The width of this component's plane.

        Requires the parent :class:`VideoFormat` to have a width.

        """
        def __get__(self):
            return self.format.chroma_width() if self.is_chroma else self.format.width

    property height:
        """The height of this component's plane.

        Requires the parent :class:`VideoFormat` to have a height.

        """
        def __get__(self):
            return self.format.chroma_height() if self.is_chroma else self.format.height


