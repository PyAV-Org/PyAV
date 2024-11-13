cimport libav as lib
from libc.stdint cimport int32_t

from enum import Enum

from av.error cimport err_check
from av.packet cimport Packet
from av.utils cimport (
    avdict_to_dict,
    avrational_to_fraction,
    dict_to_avdict,
    to_avrational,
)


cdef object _cinit_bypass_sentinel = object()

# If necessary more can be added from
# https://ffmpeg.org/doxygen/trunk/group__lavc__packet.html#ga9a80bfcacc586b483a973272800edb97
class SideData(Enum):
    DISPLAYMATRIX: "Display Matrix" = lib.AV_PKT_DATA_DISPLAYMATRIX

cdef Stream wrap_stream(Container container, lib.AVStream *c_stream, CodecContext codec_context):
    """Build an av.Stream for an existing AVStream.

    The AVStream MUST be fully constructed and ready for use before this is
    called.

    """

    # This better be the right one...
    assert container.ptr.streams[c_stream.index] == c_stream

    cdef Stream py_stream

    if c_stream.codecpar.codec_type == lib.AVMEDIA_TYPE_VIDEO:
        from av.video.stream import VideoStream
        py_stream = VideoStream.__new__(VideoStream, _cinit_bypass_sentinel)
    elif c_stream.codecpar.codec_type == lib.AVMEDIA_TYPE_AUDIO:
        from av.audio.stream import AudioStream
        py_stream = AudioStream.__new__(AudioStream, _cinit_bypass_sentinel)
    elif c_stream.codecpar.codec_type == lib.AVMEDIA_TYPE_SUBTITLE:
        from av.subtitles.stream import SubtitleStream
        py_stream = SubtitleStream.__new__(SubtitleStream, _cinit_bypass_sentinel)
    elif c_stream.codecpar.codec_type == lib.AVMEDIA_TYPE_ATTACHMENT:
        from av.attachments.stream import AttachmentStream
        py_stream = AttachmentStream.__new__(AttachmentStream, _cinit_bypass_sentinel)
    elif c_stream.codecpar.codec_type == lib.AVMEDIA_TYPE_DATA:
        from av.data.stream import DataStream
        py_stream = DataStream.__new__(DataStream, _cinit_bypass_sentinel)
    else:
        py_stream = Stream.__new__(Stream, _cinit_bypass_sentinel)

    py_stream._init(container, c_stream, codec_context)
    return py_stream


cdef class Stream:
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

    cdef _init(self, Container container, lib.AVStream *stream, CodecContext codec_context):
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

        # Convenience setter for codec context properties.
        if self.codec_context is not None:
            setattr(self.codec_context, name, value)

        if name == "time_base":
            self._set_time_base(value)

    cdef _finalize_for_output(self):

        dict_to_avdict(
            &self.ptr.metadata, self.metadata,
            encoding=self.container.metadata_encoding,
            errors=self.container.metadata_errors,
        )

        if not self.ptr.time_base.num:
            self.ptr.time_base = self.codec_context.ptr.time_base

        # It prefers if we pass it parameters via this other object.
        # Lets just copy what we want.
        err_check(lib.avcodec_parameters_from_context(self.ptr.codecpar, self.codec_context.ptr))

    @property
    def id(self):
        """
        The format-specific ID of this stream.

        :type: int

        """
        return self.ptr.id

    cdef _set_id(self, value):
        """
        Setter used by __setattr__ for the id property.
        """
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

        :type: :class:`~fractions.Fraction` or ``None``

        """
        return avrational_to_fraction(&self.ptr.time_base)

    cdef _set_time_base(self, value):
        """
        Setter used by __setattr__ for the time_base property.
        """
        to_avrational(value, &self.ptr.time_base)

    @property
    def start_time(self):
        """
        The presentation timestamp in :attr:`time_base` units of the first
        frame in this stream.

        :type: :class:`int` or ``None``
        """
        if self.ptr.start_time != lib.AV_NOPTS_VALUE:
            return self.ptr.start_time

    @property
    def duration(self):
        """
        The duration of this stream in :attr:`time_base` units.

        :type: :class:`int` or ``None``

        """
        if self.ptr.duration != lib.AV_NOPTS_VALUE:
            return self.ptr.duration

    @property
    def frames(self):
        """
        The number of frames this stream contains.

        Returns ``0`` if it is not known.

        :type: :class:`int`
        """
        return self.ptr.nb_frames

    @property
    def language(self):
        """
        The language of the stream.

        :type: :class:`str` or ``None``
        """
        return self.metadata.get("language")

    @property
    def type(self):
        """
        The type of the stream.

        Examples: ``'audio'``, ``'video'``, ``'subtitle'``.

        :type: str
        """
        return lib.av_get_media_type_string(self.ptr.codecpar.codec_type)
