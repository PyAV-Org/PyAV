import cython
from cython import uint as cuint

_cinit_bypass_sentinel = cython.declare(object, object())


@cython.cfunc
def get_video_format(
    c_format: lib.AVPixelFormat, width: cuint, height: cuint
) -> VideoFormat | None:
    if c_format == lib.AV_PIX_FMT_NONE:
        return None

    format: VideoFormat = VideoFormat.__new__(VideoFormat, _cinit_bypass_sentinel)
    format._init(c_format, width, height)
    return format


@cython.cfunc
@cython.exceptval(lib.AV_PIX_FMT_NONE, check=False)
def get_pix_fmt(name: cython.p_const_char) -> lib.AVPixelFormat:
    """Wrapper for lib.av_get_pix_fmt with error checking."""

    pix_fmt: lib.AVPixelFormat = lib.av_get_pix_fmt(name)
    if pix_fmt == lib.AV_PIX_FMT_NONE:
        raise ValueError("not a pixel format: %r" % name)
    return pix_fmt


@cython.cclass
class VideoFormat:
    """

    >>> format = VideoFormat('rgb24')
    >>> format.name
    'rgb24'

    """

    def __cinit__(self, name, width=0, height=0):
        if name is _cinit_bypass_sentinel:
            return

        if isinstance(name, VideoFormat):
            other: VideoFormat = cython.cast(VideoFormat, name)
            self._init(other.pix_fmt, width or other.width, height or other.height)
            return

        pix_fmt: lib.AVPixelFormat = get_pix_fmt(name)
        self._init(pix_fmt, width, height)

    @cython.cfunc
    def _init(self, pix_fmt: lib.AVPixelFormat, width: cuint, height: cuint):
        self.pix_fmt = pix_fmt
        self.ptr = lib.av_pix_fmt_desc_get(pix_fmt)
        self.width = width
        self.height = height
        self.components = tuple(
            VideoFormatComponent(self, i) for i in range(self.ptr.nb_components)
        )

    def __repr__(self):
        if self.width or self.height:
            return f"<av.{self.__class__.__name__} {self.name}, {self.width}x{self.height}>"
        else:
            return f"<av.{self.__class__.__name__} {self.name}>"

    def __int__(self):
        return int(self.pix_fmt)

    @property
    def name(self):
        """Canonical name of the pixel format."""
        return cython.cast(str, self.ptr.name)

    @property
    def bits_per_pixel(self):
        return lib.av_get_bits_per_pixel(self.ptr)

    @property
    def padded_bits_per_pixel(self):
        return lib.av_get_padded_bits_per_pixel(self.ptr)

    @property
    def is_big_endian(self):
        """Pixel format is big-endian."""
        return bool(self.ptr.flags & lib.AV_PIX_FMT_FLAG_BE)

    @property
    def has_palette(self):
        """Pixel format has a palette in data[1], values are indexes in this palette."""
        return bool(self.ptr.flags & lib.AV_PIX_FMT_FLAG_PAL)

    @property
    def is_bit_stream(self):
        """All values of a component are bit-wise packed end to end."""
        return bool(self.ptr.flags & lib.AV_PIX_FMT_FLAG_BITSTREAM)

    @property
    def is_planar(self):
        """At least one pixel component is not in the first data plane."""
        return bool(self.ptr.flags & lib.AV_PIX_FMT_FLAG_PLANAR)

    @property
    def is_rgb(self):
        """The pixel format contains RGB-like data (as opposed to YUV/grayscale)."""
        return bool(self.ptr.flags & lib.AV_PIX_FMT_FLAG_RGB)

    @property
    def is_bayer(self):
        """The pixel format contains Bayer data."""
        return bool(self.ptr.flags & lib.AV_PIX_FMT_FLAG_BAYER)

    @cython.ccall
    def chroma_width(self, luma_width: cython.int = 0):
        """chroma_width(luma_width=0)

        Width of a chroma plane relative to a luma plane.

        :param int luma_width: Width of the luma plane; defaults to ``self.width``.

        """
        luma_width = luma_width or self.width
        return -((-luma_width) >> self.ptr.log2_chroma_w) if luma_width else 0

    @cython.ccall
    def chroma_height(self, luma_height: cython.int = 0):
        """chroma_height(luma_height=0)

        Height of a chroma plane relative to a luma plane.

        :param int luma_height: Height of the luma plane; defaults to ``self.height``.

        """
        luma_height = luma_height or self.height
        return -((-luma_height) >> self.ptr.log2_chroma_h) if luma_height else 0


@cython.cclass
class VideoFormatComponent:
    def __cinit__(self, format: VideoFormat, index: cython.size_t):
        self.format = format
        self.index = index
        self.ptr = cython.address(format.ptr.comp[index])

    @property
    def plane(self):
        """The index of the plane which contains this component."""
        return self.ptr.plane

    @property
    def bits(self):
        """Number of bits in the component."""
        return self.ptr.depth

    @property
    def is_alpha(self):
        """Is this component an alpha channel?"""
        return (self.index == 1 and self.format.ptr.nb_components == 2) or (
            self.index == 3 and self.format.ptr.nb_components == 4
        )

    @property
    def is_luma(self):
        """Is this component a luma channel?"""
        return self.index == 0 and (
            self.format.ptr.nb_components == 1
            or self.format.ptr.nb_components == 2
            or not self.format.is_rgb
        )

    @property
    def is_chroma(self):
        """Is this component a chroma channel?"""
        return (self.index == 1 or self.index == 2) and (
            self.format.ptr.log2_chroma_w or self.format.ptr.log2_chroma_h
        )

    @property
    def width(self):
        """The width of this component's plane.

        Requires the parent :class:`VideoFormat` to have a width.

        """
        return self.format.chroma_width() if self.is_chroma else self.format.width

    @property
    def height(self):
        """The height of this component's plane.

        Requires the parent :class:`VideoFormat` to have a height.

        """
        return self.format.chroma_height() if self.is_chroma else self.format.height


names = set()
desc = cython.declare(cython.pointer[lib.AVPixFmtDescriptor], cython.NULL)
while True:
    desc = lib.av_pix_fmt_desc_next(desc)
    if not desc:
        break
    names.add(desc.name)
