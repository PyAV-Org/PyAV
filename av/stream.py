from enum import Flag

import cython
from cython.cimports import libav as lib
from cython.cimports.av.error import err_check
from cython.cimports.av.packet import Packet
from cython.cimports.av.utils import (
    avdict_to_dict,
    avrational_to_fraction,
    dict_to_avdict,
    to_avrational,
)


class Disposition(Flag):
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
    def type(self):
        """
        The type of the stream.

        :type: Literal["audio", "video", "subtitle", "data", "attachment"]
        """
        return lib.av_get_media_type_string(self.ptr.codecpar.codec_type)


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
