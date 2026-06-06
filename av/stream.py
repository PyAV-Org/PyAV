import struct
from enum import IntEnum, IntFlag

import cython
from cython.cimports import libav as lib
from cython.cimports.av.error import err_check
from cython.cimports.av.index import wrap_index_entries
from cython.cimports.av.utils import (
    avdict_to_dict,
    avrational_to_fraction,
    dict_to_avdict,
    to_avrational,
)
from cython.cimports.libc.stdint import int32_t


class Disposition(IntFlag):
    default = 1 << 0
    dub = 1 << 1
    original = 1 << 2
    comment = 1 << 3
    lyrics = 1 << 4
    karaoke = 1 << 5
    forced = 1 << 6
    hearing_impaired = 1 << 7
    visual_impaired = 1 << 8
    clean_effects = 1 << 9
    attached_pic = 1 << 10
    timed_thumbnails = 1 << 11
    non_diegetic = 1 << 12
    captions = 1 << 16
    descriptions = 1 << 17
    metadata = 1 << 18
    dependent = 1 << 19
    still_image = 1 << 20
    multilayer = 1 << 21


class Discard(IntEnum):
    none = lib.AVDISCARD_NONE
    default = lib.AVDISCARD_DEFAULT
    nonref = lib.AVDISCARD_NONREF
    bidir = lib.AVDISCARD_BIDIR
    nonintra = lib.AVDISCARD_NONINTRA
    nonkey = lib.AVDISCARD_NONKEY
    all = lib.AVDISCARD_ALL


_cinit_bypass_sentinel = cython.declare(object, object())


@cython.cfunc
def wrap_stream(
    container: Container,
    c_stream: cython.pointer[lib.AVStream],
    codec_context: CodecContext,
) -> Stream:
    """Build an av.Stream for an existing AVStream.

    The AVStream MUST be fully constructed and ready for use before this is called.
    """

    # This better be the right one...
    assert container.ptr.streams[c_stream.index] == c_stream

    py_stream: Stream

    from av.audio.stream import AudioStream
    from av.subtitles.stream import SubtitleStream
    from av.video.stream import VideoStream

    if c_stream.codecpar.codec_type == lib.AVMEDIA_TYPE_VIDEO:
        py_stream = VideoStream.__new__(VideoStream, _cinit_bypass_sentinel)
    elif c_stream.codecpar.codec_type == lib.AVMEDIA_TYPE_AUDIO:
        py_stream = AudioStream.__new__(AudioStream, _cinit_bypass_sentinel)
    elif c_stream.codecpar.codec_type == lib.AVMEDIA_TYPE_SUBTITLE:
        py_stream = SubtitleStream.__new__(SubtitleStream, _cinit_bypass_sentinel)
    elif c_stream.codecpar.codec_type == lib.AVMEDIA_TYPE_ATTACHMENT:
        py_stream = AttachmentStream.__new__(AttachmentStream, _cinit_bypass_sentinel)
    elif c_stream.codecpar.codec_type == lib.AVMEDIA_TYPE_DATA:
        py_stream = DataStream.__new__(DataStream, _cinit_bypass_sentinel)
    else:
        py_stream = Stream.__new__(Stream, _cinit_bypass_sentinel)

    py_stream._init(container, c_stream, codec_context)
    return py_stream


@cython.cclass
class Stream:
    """
    A single stream of audio, video or subtitles within a :class:`.Container`.

    ::

        >>> fh = av.open(video_path)
        >>> stream = fh.streams.video[0]
        >>> stream
        <av.VideoStream #0 h264, yuv420p 1280x720 at 0x...>

    This encapsulates a :class:`.CodecContext`, located at :attr:`Stream.codec_context`.
    Attribute access is passed through to that context when attributes are missing
    on the stream itself. E.g. ``stream.options`` will be the options on the
    context.
    """

    def __cinit__(self, name):
        if name is _cinit_bypass_sentinel:
            return
        raise RuntimeError("cannot manually instantiate Stream")

    @cython.cfunc
    def _init(
        self,
        container: Container,
        stream: cython.pointer[lib.AVStream],
        codec_context: CodecContext,
    ):
        self.container = container
        self.ptr = stream
        self.index_entries = wrap_index_entries(self.ptr)

        self.codec_context = codec_context
        if self.codec_context:
            self.codec_context.stream_index = stream.index

        self.metadata = avdict_to_dict(
            stream.metadata,
            encoding=self.container.metadata_encoding,
            errors=self.container.metadata_errors,
        )

    def __repr__(self):
        name = getattr(self, "name", None)
        return (
            f"<av.{self.__class__.__name__} #{self.index} {self.type or '<notype>'}/"
            f"{name or '<nocodec>'} at 0x{id(self):x}>"
        )

    def __setattr__(self, name, value):
        if name == "id":
            self._set_id(value)
            return
        if name == "disposition":
            self.ptr.disposition = value
            return
        if name == "discard":
            self.ptr.discard = Discard(value).value
            return
        if name == "time_base":
            to_avrational(value, cython.address(self.ptr.time_base))
            return

        # Convenience setter for codec context properties.
        if self.codec_context is not None:
            setattr(self.codec_context, name, value)

    @cython.cfunc
    def _finalize_for_output(self):
        dict_to_avdict(
            cython.address(self.ptr.metadata),
            self.metadata,
            encoding=self.container.metadata_encoding,
            errors=self.container.metadata_errors,
        )

        if self.codec_context is None:
            return

        if not self.ptr.time_base.num:
            self.ptr.time_base = self.codec_context.ptr.time_base

        # It prefers if we pass it parameters via this other object. Let's just copy what we want.
        err_check(
            lib.avcodec_parameters_from_context(
                self.ptr.codecpar, self.codec_context.ptr
            )
        )

        # avcodec_parameters_from_context() frees and overwrites
        # codecpar.coded_side_data, so the display matrix must be injected
        # *after* it, right before avformat_write_header() consumes it.
        if self._display_matrix is not None or self._display_rotation is not None:
            self._apply_display_matrix()

    @cython.cfunc
    def _apply_display_matrix(self):
        sd: cython.pointer[lib.AVPacketSideData] = lib.av_packet_side_data_new(
            cython.address(self.ptr.codecpar.coded_side_data),
            cython.address(self.ptr.codecpar.nb_coded_side_data),
            lib.AV_PKT_DATA_DISPLAYMATRIX,
            36,
            0,
        )
        if sd == cython.NULL:
            raise MemoryError("could not allocate display matrix side data")

        if self._display_matrix is not None:
            data: cython.pointer[cython.uchar] = sd.data
            i: cython.int
            for i in range(36):
                data[i] = self._display_matrix[i]
            return

        # Convenience path: build the matrix in place with FFmpeg's helpers.
        angle: cython.double = self._display_rotation[0]
        hflip: cython.int = self._display_rotation[1]
        vflip: cython.int = self._display_rotation[2]
        matrix: cython.pointer[int32_t] = cython.cast(cython.pointer[int32_t], sd.data)
        # av_display_rotation_set() takes a clockwise angle; negate so our public
        # `degrees` is counter-clockwise, matching VideoFrame.rotation on read.
        lib.av_display_rotation_set(matrix, -angle)
        lib.av_display_matrix_flip(matrix, hflip, vflip)

    def set_display_matrix(self, matrix):
        """Set the display (rotation) matrix written to the container.

        ``matrix`` is a sequence of 9 integers in FFmpeg's display-matrix
        layout (16.16 fixed point for entries 0,1,3,4,6,7 and 2.30 fixed point
        for entries 2,5,8), matching ``AV_PKT_DATA_DISPLAYMATRIX``. The values
        are written, native-endian, as coded side data on the output stream so
        the muxer records them in the container (e.g. the MP4/MOV ``tkhd``
        transformation matrix). Pass ``None`` to clear.

        Must be called before the first frame is encoded / the header is
        written. See :meth:`set_display_rotation` for a higher-level helper.
        """
        self._display_rotation = None
        if matrix is None:
            self._display_matrix = None
            return

        vals = [int(v) for v in matrix]
        if len(vals) != 9:
            raise ValueError("display matrix must have exactly 9 elements")
        self._display_matrix = struct.pack("=9i", *vals)

    def set_display_rotation(self, degrees, hflip=False, vflip=False):
        """Set the container display matrix from a rotation and optional flips.

        ``degrees`` is a counter-clockwise rotation (matching the value read
        back from :attr:`VideoFrame.rotation`); ``hflip`` / ``vflip`` apply a
        horizontal / vertical mirror after the rotation. Together these express
        all eight EXIF orientations. The matrix is built with FFmpeg's
        ``av_display_rotation_set`` / ``av_display_matrix_flip`` and written as
        coded side data on the output stream (e.g. the MP4/MOV ``tkhd`` matrix).

        This is a convenience wrapper over :meth:`set_display_matrix`; it must
        likewise be called before the first frame is encoded.
        """
        self._display_matrix = None
        self._display_rotation = (float(degrees), bool(hflip), bool(vflip))

    @property
    def id(self):
        """
        The format-specific ID of this stream.

        :type: int

        """
        return self.ptr.id

    @cython.cfunc
    def _set_id(self, value):
        if value is None:
            self.ptr.id = 0
        else:
            self.ptr.id = value

    @property
    def profiles(self):
        """
        List the available profiles for this stream.

        :type: list[str]
        """
        if self.codec_context:
            return self.codec_context.profiles
        else:
            return []

    @property
    def profile(self):
        """
        The profile of this stream.

        :type: str
        """
        if self.codec_context:
            return self.codec_context.profile
        else:
            return None

    @property
    def index(self):
        """
        The index of this stream in its :class:`.Container`.

        :type: int
        """
        return self.ptr.index

    @property
    def time_base(self):
        """
        The unit of time (in fractional seconds) in which timestamps are expressed.

        :type: fractions.Fraction | None

        """
        return avrational_to_fraction(cython.address(self.ptr.time_base))

    @property
    def start_time(self):
        """
        The presentation timestamp in :attr:`time_base` units of the first
        frame in this stream.

        :type: int | None
        """
        if self.ptr.start_time != lib.AV_NOPTS_VALUE:
            return self.ptr.start_time

    @property
    def duration(self):
        """
        The duration of this stream in :attr:`time_base` units.

        :type: int | None

        """
        if self.ptr.duration != lib.AV_NOPTS_VALUE:
            return self.ptr.duration

    @property
    def frames(self):
        """
        The number of frames this stream contains.

        Returns ``0`` if it is not known.

        :type: int
        """
        return self.ptr.nb_frames

    @property
    def language(self):
        """
        The language of the stream.

        :type: str | None
        """
        return self.metadata.get("language")

    @property
    def disposition(self):
        return Disposition(self.ptr.disposition)

    @property
    def discard(self):
        """
        Controls which packets of this stream are discarded by the demuxer.

        Set this to e.g. :attr:`Discard.all` on streams you don't need so that
        :meth:`.Container.demux` and :meth:`.Container.seek` skip them, avoiding
        the cost of synchronizing streams you never read.

        :type: Discard
        """
        return Discard(self.ptr.discard)

    @property
    def type(self):
        """
        The type of the stream.

        :type: Literal["audio", "video", "subtitle", "data", "attachment"]
        """
        media_type = lib.av_get_media_type_string(self.ptr.codecpar.codec_type)
        return "unknown" if media_type == cython.NULL else media_type


@cython.final
@cython.cclass
class DataStream(Stream):
    def __repr__(self):
        return (
            f"<av.{self.__class__.__name__} #{self.index} data/"
            f"{self.name or '<nocodec>'} at 0x{id(self):x}>"
        )

    @property
    def name(self):
        desc: cython.pointer[cython.const[lib.AVCodecDescriptor]] = (
            lib.avcodec_descriptor_get(self.ptr.codecpar.codec_id)
        )
        if desc == cython.NULL:
            return None
        return desc.name


@cython.final
@cython.cclass
class AttachmentStream(Stream):
    """
    An :class:`AttachmentStream` represents a stream of attachment data within a media container.
    Typically used to attach font files that are referenced in ASS/SSA Subtitle Streams.
    """

    @property
    def name(self):
        """
        Returns the file name of the attachment.

        :rtype: str | None
        """
        return self.metadata.get("filename")

    @property
    def mimetype(self):
        """
        Returns the MIME type of the attachment.

        :rtype: str | None
        """
        return self.metadata.get("mimetype")

    @property
    def data(self):
        """Return the raw attachment payload as bytes."""
        extradata: cython.p_uchar = self.ptr.codecpar.extradata
        size: cython.Py_ssize_t = self.ptr.codecpar.extradata_size
        if extradata == cython.NULL or size <= 0:
            return b""

        payload = bytearray(size)
        for i in range(size):
            payload[i] = extradata[i]

        return bytes(payload)
