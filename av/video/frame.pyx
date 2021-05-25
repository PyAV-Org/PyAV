from libc.stdint cimport uint8_t

from av.enum cimport define_enum
from av.error cimport err_check
from av.utils cimport avrational_to_fraction
from av.video.format cimport VideoFormat, get_video_format
from av.video.plane cimport VideoPlane

from av.deprecation import renamed_attr


cdef object _cinit_bypass_sentinel

cdef VideoFrame alloc_video_frame():
    """Get a mostly uninitialized VideoFrame.

    You MUST call VideoFrame._init(...) or VideoFrame._init_user_attributes()
    before exposing to the user.

    """
    return VideoFrame.__new__(VideoFrame, _cinit_bypass_sentinel)


PictureType = define_enum('PictureType', __name__, (
    ('NONE', lib.AV_PICTURE_TYPE_NONE, "Undefined"),
    ('I', lib.AV_PICTURE_TYPE_I, "Intra"),
    ('P', lib.AV_PICTURE_TYPE_P, "Predicted"),
    ('B', lib.AV_PICTURE_TYPE_B, "Bi-directional predicted"),
    ('S', lib.AV_PICTURE_TYPE_S, "S(GMC)-VOP MPEG-4"),
    ('SI', lib.AV_PICTURE_TYPE_SI, "Switching intra"),
    ('SP', lib.AV_PICTURE_TYPE_SP, "Switching predicted"),
    ('BI', lib.AV_PICTURE_TYPE_BI, "BI type"),
))

ColorPrimariesType = define_enum('ColorPrimariesType', __name__, (
    ('reserved0', lib.AVCOL_PRI_RESERVED0, 'Reserved (0)'),
    ('bt709', lib.AVCOL_PRI_BT709, 'bt709'),
    ('unknown', lib.AVCOL_PRI_UNSPECIFIED, 'Unspecified'),
    ('reserved', lib.AVCOL_PRI_RESERVED, 'Reserved'),
    ('bt470m', lib.AVCOL_PRI_BT470M, 'bt470m'),
    ('bt470bg', lib.AVCOL_PRI_BT470BG, 'bt470bg'),
    ('smpte170m', lib.AVCOL_PRI_SMPTE170M, 'smpte170m'),
    ('smpte240m', lib.AVCOL_PRI_SMPTE240M, 'smpte240m'),
    ('film', lib.AVCOL_PRI_FILM, 'Film'),
    ('bt2020', lib.AVCOL_PRI_BT2020, 'ITU-R BT2020'),
    ('smpte428', lib.AVCOL_PRI_SMPTE428, 'SMPTE ST 428-1 (CIE 1931 XYZ)'),
    ('smpte431', lib.AVCOL_PRI_SMPTE431, 'SMPTE ST 431-2 (2011) / DCI P3'),
    ('smpte432', lib.AVCOL_PRI_SMPTE432, 'SMPTE ST 432-1 (2010) / P3 D65 / Display P3'),
    # AVCOL_PRI_EBU3213  # introduced in n4.4-dev:
    #   (LIBAVUTIL_VERSION_MAJOR, LIBAVUTIL_VERSION_MINOR, LIBAVUTIL_VERSION_MICRO) > (56, 34, 100)
    # ('ebu3213', lib.AVCOL_PRI_EBU3213, 'EBU Tech. 3213-E / JEDEC P22 phosphors'),
))

ColorTransferCharacteristicType = define_enum('ColorTransferCharacteristicType', __name__, (
    ('reserved0', lib.AVCOL_TRC_RESERVED0, 'Reserved (0)'),
    ('bt709', lib.AVCOL_TRC_BT709, 'bt709'),
    ('unknown', lib.AVCOL_TRC_UNSPECIFIED, 'Unspecified'),
    ('reserved', lib.AVCOL_TRC_RESERVED, 'Reserved'),
    ('bt470m', lib.AVCOL_TRC_GAMMA22, 'bt470m'),
    ('bt470bg', lib.AVCOL_TRC_GAMMA28, 'bt470bg'),
    ('smpte170m', lib.AVCOL_TRC_SMPTE170M, 'smpte170m'),
    ('smpte240m', lib.AVCOL_TRC_SMPTE240M, 'smpte240m'),
    ('linear', lib.AVCOL_TRC_LINEAR, 'Linear transfer characteristics'),
    ('log100', lib.AVCOL_TRC_LOG, 'Logarithmic transfer characteristic'),
    ('log316', lib.AVCOL_TRC_LOG_SQRT, 'Logarithmic transfer characteristic'),
    ('iec61966-2-4', lib.AVCOL_TRC_IEC61966_2_4, 'IEC 61966-2-4'),
    ('bt1361e', lib.AVCOL_TRC_BT1361_ECG, 'ITU-R BT1361 Extended Colour Gamut'),
    ('iec61966-2-1', lib.AVCOL_TRC_IEC61966_2_1, 'IEC 61966-2-1 (sRGB or sYCC)'),
    ('bt2020-10', lib.AVCOL_TRC_BT2020_10, 'ITU-R BT2020 for 10-bit system'),
    ('bt2020-12', lib.AVCOL_TRC_BT2020_12, 'ITU-R BT2020 for 12-bit system'),
    ('smpte2084', lib.AVCOL_TRC_SMPTE2084, 'SMPTE ST 2084 for 10-, 12-, 14- and 16-bit systems'),
    ('smpte428', lib.AVCOL_TRC_SMPTE428, 'SMPTE ST 428-1'),
    ('arib-std-b67', lib.AVCOL_TRC_ARIB_STD_B67, 'ARIB STD-B67 (Hybrid log-gamma)'),
))


ColorSpaceType = define_enum('ColorSpaceType', __name__, (
    ('gbr', lib.AVCOL_SPC_RGB, 'RGB/GBR/IEC 61966-2-1 (sRGB)'),
    ('bt709', lib.AVCOL_SPC_BT709, 'bt709'),
    ('unknown', lib.AVCOL_SPC_UNSPECIFIED, 'Unspecified'),
    ('reserved', lib.AVCOL_SPC_RESERVED, 'Reserved'),
    ('fcc', lib.AVCOL_SPC_FCC, 'FCC Title 47 Code of Federal Regulations 73.682 (a)(20)'),
    ('bt470bg', lib.AVCOL_SPC_BT470BG, 'bt470bg'),
    ('smpte170m', lib.AVCOL_SPC_SMPTE170M, 'smpte170m'),
    ('smpte240m', lib.AVCOL_SPC_SMPTE240M, 'smpte240m'),
    ('ycgco', lib.AVCOL_SPC_YCGCO, 'ycgco'),
    ('bt2020nc', lib.AVCOL_SPC_BT2020_NCL, 'ITU-R BT2020 non-constant luminance system'),
    ('bt2020c', lib.AVCOL_SPC_BT2020_CL, 'ITU-R BT2020 constant luminance system'),
    ('smpte2085', lib.AVCOL_SPC_SMPTE2085, 'SMPTE 2085, Y\'D\'zD\'x'),
    ('chroma-derived-nc', lib.AVCOL_SPC_CHROMA_DERIVED_NCL, 'Chromaticity-derived non-constant luminance system'),
    ('chroma-derived-c', lib.AVCOL_SPC_CHROMA_DERIVED_CL, 'Chromaticity-derived constant luminance system'),
    ('ictcp', lib.AVCOL_SPC_ICTCP, 'ITU-R BT.2100-0, ICtCp'),
))

ColorRangeType = define_enum('ColorRangeType', __name__, (
    ('unknown', lib.AVCOL_RANGE_UNSPECIFIED, 'Unspecified'),
    ('tv', lib.AVCOL_RANGE_MPEG, 'MPEG (tv)'),
    ('pc', lib.AVCOL_RANGE_JPEG, 'JPEG (pc)'),
))

ChromaLocationType = define_enum('ChromaLocationType', __name__, (
    ('unknown', lib.AVCHROMA_LOC_UNSPECIFIED, 'Unspecified'),
    ('left', lib.AVCHROMA_LOC_LEFT, 'Left'),
    ('center', lib.AVCHROMA_LOC_CENTER, 'Center'),
    ('topleft', lib.AVCHROMA_LOC_TOPLEFT, 'Top left'),
    ('top', lib.AVCHROMA_LOC_TOP, 'Top'),
    ('bottomleft', lib.AVCHROMA_LOC_BOTTOMLEFT, 'Bottom left'),
    ('bottom', lib.AVCHROMA_LOC_BOTTOM, 'Bottom'),
))

cdef copy_array_to_plane(array, VideoPlane plane, unsigned int bytes_per_pixel):
    cdef bytes imgbytes = array.tobytes()
    cdef const uint8_t[:] i_buf = imgbytes
    cdef size_t i_pos = 0
    cdef size_t i_stride = plane.width * bytes_per_pixel
    cdef size_t i_size = plane.height * i_stride

    cdef uint8_t[:] o_buf = plane
    cdef size_t o_pos = 0
    cdef size_t o_stride = abs(plane.line_size)

    while i_pos < i_size:
        o_buf[o_pos:o_pos + i_stride] = i_buf[i_pos:i_pos + i_stride]
        i_pos += i_stride
        o_pos += o_stride


cdef useful_array(VideoPlane plane, unsigned int bytes_per_pixel=1):
    """
    Return the useful part of the VideoPlane as a single dimensional array.

    We are simply discarding any padding which was added for alignment.
    """
    import numpy as np
    cdef size_t total_line_size = abs(plane.line_size)
    cdef size_t useful_line_size = plane.width * bytes_per_pixel
    arr = np.frombuffer(plane, np.uint8)
    if total_line_size != useful_line_size:
        arr = arr.reshape(-1, total_line_size)[:, 0:useful_line_size].reshape(-1)
    return arr


cdef class VideoFrame(Frame):

    def __cinit__(self, width=0, height=0, format='yuv420p'):

        if width is _cinit_bypass_sentinel:
            return

        cdef lib.AVPixelFormat c_format = lib.av_get_pix_fmt(format)
        if c_format < 0:
            raise ValueError('invalid format %r' % format)

        self._init(c_format, width, height)

    cdef _init(self, lib.AVPixelFormat format, unsigned int width, unsigned int height):

        cdef int res = 0

        with nogil:
            self.ptr.width = width
            self.ptr.height = height
            self.ptr.format = format

            # Allocate the buffer for the video frame.
            #
            # We enforce aligned buffers, otherwise `sws_scale` can perform
            # poorly or even cause out-of-bounds reads and writes.
            if width and height:
                res = lib.av_image_alloc(
                    self.ptr.data,
                    self.ptr.linesize,
                    width,
                    height,
                    format,
                    16)
                self._buffer = self.ptr.data[0]

        if res:
            err_check(res)

        self._init_user_attributes()

    cdef _init_user_attributes(self):
        self.format = get_video_format(<lib.AVPixelFormat>self.ptr.format, self.ptr.width, self.ptr.height)

    def __dealloc__(self):
        # The `self._buffer` member is only set if *we* allocated the buffer in `_init`,
        # as opposed to a buffer allocated by a decoder.
        lib.av_freep(&self._buffer)

    def __repr__(self):
        return '<av.%s #%d, pts=%s %s %dx%d at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.pts,
            self.format.name if self.format is not None else None,
            self.width,
            self.height,
            id(self),
        )

    @property
    def planes(self):
        """
        A tuple of :class:`.VideoPlane` objects.
        """
        # We need to detect which planes actually exist, but also contrain
        # ourselves to the maximum plane count (as determined only by VideoFrames
        # so far), in case the library implementation does not set the last
        # plane to NULL.
        cdef int max_plane_count = 0
        for i in range(self.format.ptr.nb_components):
            count = self.format.ptr.comp[i].plane + 1
            if max_plane_count < count:
                max_plane_count = count
        if self.format.name == 'pal8':
            max_plane_count = 2

        cdef int plane_count = 0
        while plane_count < max_plane_count and self.ptr.extended_data[plane_count]:
            plane_count += 1

        return tuple([VideoPlane(self, i) for i in range(plane_count)])

    property width:
        """Width of the image, in pixels."""
        def __get__(self): return self.ptr.width

    property height:
        """Height of the image, in pixels."""
        def __get__(self): return self.ptr.height

    property repeat_pict:
        """When decoding, this signals how much the picture must be delayed.

        Wraps :ffmpeg:`AVFrame.repeat_pict`.

        """
        def __get__(self): return self.ptr.repeat_pict

    property interlaced_frame:
        """Is this frame an interlaced or progressive?

        Wraps :ffmpeg:`AVFrame.interlaced_frame`.

        """
        def __get__(self): return self.ptr.interlaced_frame

    property top_field_first:
        """If the content is interlaced, is top field displayed first.

        Wraps :ffmpeg:`AVFrame.top_field_first`.

        """
        def __get__(self): return self.ptr.top_field_first

    property sample_aspect_ratio:
        """Sample aspect ratio for the video frame, 0/1 if unknown/unspecified.

        Wraps :ffmpeg:`AVFrame.sample_aspect_ratio`.

        """
        def __get__(self):
            return avrational_to_fraction(&self.ptr.sample_aspect_ratio)

    property coded_picture_number:
        """picture number in bitstream order

        Wraps :ffmpeg:`AVFrame.coded_picture_number`.

        """
        def __get__(self): return self.ptr.coded_picture_number

    property display_picture_number:
        """picture number in display order

        Wraps :ffmpeg:`AVFrame.display_picture_number`.

        """
        def __get__(self): return self.ptr.display_picture_number

    @property
    def pict_type(self):
        """One of :class:`.PictureType`.

        Wraps :ffmpeg:`AVFrame.pict_type`.

        """
        return PictureType.get(self.ptr.pict_type, create=True)

    @pict_type.setter
    def pict_type(self, value):
        self.ptr.pict_type = PictureType[value].value

    property color_range:
        """MPEG vs JPEG YUV range

        Wraps :ffmpeg:`AVFrame.color_range`.

        """
        def __get__(self):
            if self.ptr.color_range != lib.AVCOL_RANGE_UNSPECIFIED:
                return ColorRangeType.get(self.ptr.color_range, create=True)

    property color_primaries:
        """Color primaries

        Wraps :ffmpeg:`AVFrame.color_primaries`.

        """
        def __get__(self):
            if self.ptr.color_primaries != lib.AVCOL_PRI_UNSPECIFIED:
                return ColorPrimariesType.get(self.ptr.color_primaries, create=True)

    property color_trc:
        """Color transfer characteristics

        Wraps :ffmpeg:`AVFrame.color_trc`.

        """
        def __get__(self):
            if self.ptr.color_trc != lib.AVCOL_TRC_UNSPECIFIED:
                return ColorTransferCharacteristicType.get(self.ptr.color_trc, create=True)

    property color_space:
        """YUV colorspace type

        Wraps :ffmpeg:`AVFrame.colorspace`.

        """
        def __get__(self):
            if self.ptr.colorspace != lib.AVCOL_SPC_UNSPECIFIED:
                return ColorSpaceType.get(self.ptr.colorspace, create=True)

    property chroma_location:
        """Chroma location

        Wraps :ffmpeg:`AVFrame.chroma_location`.

        """
        def __get__(self):
            if self.ptr.chroma_location != lib.AVCHROMA_LOC_UNSPECIFIED:
                return ChromaLocationType.get(self.ptr.chroma_location, create=True)

    def reformat(self, *args, **kwargs):
        """reformat(width=None, height=None, format=None, src_colorspace=None, dst_colorspace=None, interpolation=None)

        Create a new :class:`VideoFrame` with the given width/height/format/colorspace.

        .. seealso:: :meth:`.VideoReformatter.reformat` for arguments.

        """
        if not self.reformatter:
            self.reformatter = VideoReformatter()
        return self.reformatter.reformat(self, *args, **kwargs)

    def to_rgb(self, **kwargs):
        """Get an RGB version of this frame.

        Any ``**kwargs`` are passed to :meth:`.VideoReformatter.reformat`.

        >>> frame = VideoFrame(1920, 1080)
        >>> frame.format.name
        'yuv420p'
        >>> frame.to_rgb().format.name
        'rgb24'

        """
        return self.reformat(format="rgb24", **kwargs)

    def to_image(self, **kwargs):
        """Get an RGB ``PIL.Image`` of this frame.

        Any ``**kwargs`` are passed to :meth:`.VideoReformatter.reformat`.

        .. note:: PIL or Pillow must be installed.

        """
        from PIL import Image
        cdef VideoPlane plane = self.reformat(format="rgb24", **kwargs).planes[0]

        cdef const uint8_t[:] i_buf = plane
        cdef size_t i_pos = 0
        cdef size_t i_stride = plane.line_size

        cdef size_t o_pos = 0
        cdef size_t o_stride = plane.width * 3
        cdef size_t o_size = plane.height * o_stride
        cdef bytearray o_buf = bytearray(o_size)

        while o_pos < o_size:
            o_buf[o_pos:o_pos + o_stride] = i_buf[i_pos:i_pos + o_stride]
            i_pos += i_stride
            o_pos += o_stride

        return Image.frombytes("RGB", (self.width, self.height), bytes(o_buf), "raw", "RGB", 0, 1)

    def to_ndarray(self, **kwargs):
        """Get a numpy array of this frame.

        Any ``**kwargs`` are passed to :meth:`.VideoReformatter.reformat`.

        .. note:: Numpy must be installed.

        .. note:: For ``pal8``, an ``(image, palette)`` tuple will be returned,
        with the palette being in ARGB (PyAV will swap bytes if needed).

        """
        cdef VideoFrame frame = self.reformat(**kwargs)

        import numpy as np

        if frame.format.name in ('yuv420p', 'yuvj420p'):
            assert frame.width % 2 == 0
            assert frame.height % 2 == 0
            return np.hstack((
                useful_array(frame.planes[0]),
                useful_array(frame.planes[1]),
                useful_array(frame.planes[2])
            )).reshape(-1, frame.width)
        elif frame.format.name == 'yuyv422':
            assert frame.width % 2 == 0
            assert frame.height % 2 == 0
            return useful_array(frame.planes[0], 2).reshape(frame.height, frame.width, -1)
        elif frame.format.name in ('rgb24', 'bgr24'):
            return useful_array(frame.planes[0], 3).reshape(frame.height, frame.width, -1)
        elif frame.format.name in ('argb', 'rgba', 'abgr', 'bgra'):
            return useful_array(frame.planes[0], 4).reshape(frame.height, frame.width, -1)
        elif frame.format.name in ('gray', 'gray8', 'rgb8', 'bgr8'):
            return useful_array(frame.planes[0]).reshape(frame.height, frame.width)
        elif frame.format.name == 'pal8':
            image = useful_array(frame.planes[0]).reshape(frame.height, frame.width)
            palette = np.frombuffer(frame.planes[1], 'i4').astype('>i4').reshape(-1, 1).view(np.uint8)
            return image, palette
        else:
            raise ValueError('Conversion to numpy array with format `%s` is not yet supported' % frame.format.name)

    to_nd_array = renamed_attr('to_ndarray')

    @staticmethod
    def from_image(img):
        """
        Construct a frame from a ``PIL.Image``.
        """
        if img.mode != 'RGB':
            img = img.convert('RGB')

        cdef VideoFrame frame = VideoFrame(img.size[0], img.size[1], 'rgb24')
        copy_array_to_plane(img, frame.planes[0], 3)

        return frame

    @staticmethod
    def from_ndarray(array, format='rgb24'):
        """
        Construct a frame from a numpy array.

        .. note:: for ``pal8``, an ``(image, palette)`` pair must be passed.
        `palette` must have shape (256, 4) and is given in ARGB format
        (PyAV will swap bytes if needed).
        """
        if format == 'pal8':
            array, palette = array
            assert array.dtype == 'uint8'
            assert array.ndim == 2
            assert palette.dtype == 'uint8'
            assert palette.shape == (256, 4)
            frame = VideoFrame(array.shape[1], array.shape[0], format)
            copy_array_to_plane(array, frame.planes[0], 1)
            frame.planes[1].update(palette.view('>i4').astype('i4').tobytes())
            return frame

        if format in ('yuv420p', 'yuvj420p'):
            assert array.dtype == 'uint8'
            assert array.ndim == 2
            assert array.shape[0] % 3 == 0
            assert array.shape[1] % 2 == 0
            frame = VideoFrame(array.shape[1], (array.shape[0] * 2) // 3, format)
            u_start = frame.width * frame.height
            v_start = 5 * u_start // 4
            flat = array.reshape(-1)
            copy_array_to_plane(flat[0:u_start], frame.planes[0], 1)
            copy_array_to_plane(flat[u_start:v_start], frame.planes[1], 1)
            copy_array_to_plane(flat[v_start:], frame.planes[2], 1)
            return frame
        elif format == 'yuyv422':
            assert array.dtype == 'uint8'
            assert array.ndim == 3
            assert array.shape[0] % 2 == 0
            assert array.shape[1] % 2 == 0
            assert array.shape[2] == 2
        elif format in ('rgb24', 'bgr24'):
            assert array.dtype == 'uint8'
            assert array.ndim == 3
            assert array.shape[2] == 3
        elif format in ('argb', 'rgba', 'abgr', 'bgra'):
            assert array.dtype == 'uint8'
            assert array.ndim == 3
            assert array.shape[2] == 4
        elif format in ('gray', 'gray8', 'rgb8', 'bgr8'):
            assert array.dtype == 'uint8'
            assert array.ndim == 2
        else:
            raise ValueError('Conversion from numpy array with format `%s` is not yet supported' % format)

        frame = VideoFrame(array.shape[1], array.shape[0], format)
        copy_array_to_plane(array, frame.planes[0], 1 if array.ndim == 2 else array.shape[2])

        return frame
