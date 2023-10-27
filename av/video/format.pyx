
cdef object _cinit_bypass_sentinel = object()

cdef VideoFormat get_video_format(lib.AVPixelFormat c_format, unsigned int width, unsigned int height):
    if c_format == lib.AV_PIX_FMT_NONE:
        return None
    cdef VideoFormat format = VideoFormat.__new__(VideoFormat, _cinit_bypass_sentinel)
    format._init(c_format, width, height)
    return format

cdef lib.AVPixelFormat get_pix_fmt(const char *name) except lib.AV_PIX_FMT_NONE:
    """Wrapper for lib.av_get_pix_fmt with error checking."""

    cdef lib.AVPixelFormat pix_fmt = lib.av_get_pix_fmt(name)

    if pix_fmt == lib.AV_PIX_FMT_NONE:
        raise ValueError('not a pixel format: %r' % name)

    return pix_fmt


cdef class VideoFormat(object):
    """

        >>> format = VideoFormat('rgb24')
        >>> format.name
        'rgb24'

    """

    def __cinit__(self, name, width=0, height=0):

        if name is _cinit_bypass_sentinel:
            return

        cdef VideoFormat other
        if isinstance(name, VideoFormat):
            other = <VideoFormat>name
            self._init(other.pix_fmt, width or other.width, height or other.height)
            return

        cdef lib.AVPixelFormat pix_fmt = get_pix_fmt(name)
        self._init(pix_fmt, width, height)

    cdef _init(self, lib.AVPixelFormat pix_fmt, unsigned int width, unsigned int height):
        self.pix_fmt = pix_fmt
        self.ptr = lib.av_pix_fmt_desc_get(pix_fmt)
        self.width = width
        self.height = height
        self.components = tuple(
            VideoFormatComponent(self, i)
            for i in range(self.ptr.nb_components)
        )

    def __repr__(self):
        if self.width or self.height:
            return '<av.%s %s, %dx%d>' % (self.__class__.__name__, self.name, self.width, self.height)
        else:
            return '<av.%s %s>' % (self.__class__.__name__, self.name)

    def __int__(self):
        return int(self.pix_fmt)

    property name:
        """Canonical name of the pixel format."""
        def __get__(self):
            return <str>self.ptr.name

    property bits_per_pixel:
        def __get__(self): return lib.av_get_bits_per_pixel(self.ptr)

    property padded_bits_per_pixel:
        def __get__(self): return lib.av_get_padded_bits_per_pixel(self.ptr)

    property is_big_endian:
        """Pixel format is big-endian."""
        def __get__(self): return bool(self.ptr.flags & lib.AV_PIX_FMT_FLAG_BE)

    property has_palette:
        """Pixel format has a palette in data[1], values are indexes in this palette."""
        def __get__(self): return bool(self.ptr.flags & lib.AV_PIX_FMT_FLAG_PAL)

    property is_bit_stream:
        """All values of a component are bit-wise packed end to end."""
        def __get__(self): return bool(self.ptr.flags & lib.AV_PIX_FMT_FLAG_BITSTREAM)

    # Skipping PIX_FMT_HWACCEL
    # """Pixel format is an HW accelerated format."""

    property is_planar:
        """At least one pixel component is not in the first data plane."""
        def __get__(self): return bool(self.ptr.flags & lib.AV_PIX_FMT_FLAG_PLANAR)

    property is_rgb:
        """The pixel format contains RGB-like data (as opposed to YUV/grayscale)."""
        def __get__(self): return bool(self.ptr.flags & lib.AV_PIX_FMT_FLAG_RGB)

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
            return self.ptr.depth

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


names = set()
cdef const lib.AVPixFmtDescriptor *desc = NULL
while True:
    desc = lib.av_pix_fmt_desc_next(desc)
    if not desc:
        break
    names.add(desc.name)
