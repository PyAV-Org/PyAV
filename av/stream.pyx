import warnings

cimport libav as lib
from libc.stdint cimport int32_t

from av.enum cimport define_enum
from av.error cimport err_check
from av.packet cimport Packet
from av.utils cimport (
    avdict_to_dict,
    avrational_to_fraction,
    dict_to_avdict,
    to_avrational,
)

from av.deprecation import AVDeprecationWarning


cdef object _cinit_bypass_sentinel = object()


# If necessary more can be added from
# https://ffmpeg.org/doxygen/trunk/group__lavc__packet.html#ga9a80bfcacc586b483a973272800edb97
SideData = define_enum("SideData", __name__, (
    ("DISPLAYMATRIX", lib.AV_PKT_DATA_DISPLAYMATRIX, "Display Matrix"),
))

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

        self.nb_side_data, self.side_data = self._get_side_data(stream)
        
        self.metadata = avdict_to_dict(
            stream.metadata,
            encoding=self.container.metadata_encoding,
            errors=self.container.metadata_errors,
        )

    def __repr__(self):
        return (
            f"<av.{self.__class__.__name__} #{self.index} {self.type or '<notype>'}/"
            f"{self.name or '<nocodec>'} at 0x{id(self):x}>"
        )

    def __getattr__(self, name):
        # Deprecate framerate pass-through as it is not always set.
        # See: https://github.com/PyAV-Org/PyAV/issues/1005
        if self.ptr.codecpar.codec_type == lib.AVMEDIA_TYPE_VIDEO and name in ("framerate", "rate"):
            warnings.warn(
                f"VideoStream.{name} is deprecated as it is not always set; please use VideoStream.average_rate.",
                AVDeprecationWarning
            )

        if name == "side_data":
            return self.side_data
        elif name == "nb_side_data":
            return self.nb_side_data

        # Convenience getter for codec context properties.
        if self.codec_context is not None:
            return getattr(self.codec_context, name)

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

    def encode(self, frame=None):
        """
        Encode an :class:`.AudioFrame` or :class:`.VideoFrame` and return a list
        of :class:`.Packet`.

        :return: :class:`list` of :class:`.Packet`.

        .. seealso:: This is mostly a passthrough to :meth:`.CodecContext.encode`.
        """
        if self.codec_context is None:
            raise RuntimeError("Stream.encode requires a valid CodecContext")

        packets = self.codec_context.encode(frame)
        cdef Packet packet
        for packet in packets:
            packet._stream = self
            packet.ptr.stream_index = self.ptr.index
        return packets

    def decode(self, packet=None):
        """
        Decode a :class:`.Packet` and return a list of :class:`.AudioFrame`
        or :class:`.VideoFrame`.

        :return: :class:`list` of :class:`.Frame` subclasses.

        .. seealso:: This is mostly a passthrough to :meth:`.CodecContext.decode`.
        """
        if self.codec_context is None:
            raise RuntimeError("Stream.decode requires a valid CodecContext")

        return self.codec_context.decode(packet)

    cdef _get_side_data(self, lib.AVStream *stream):
        # Get DISPLAYMATRIX SideDate from a lib.AVStream object.
        # Returns: tuple[int, dict[str, Any]]

        nb_side_data = stream.nb_side_data
        side_data = {}
        
        for i in range(nb_side_data):
            # Based on: https://www.ffmpeg.org/doxygen/trunk/dump_8c_source.html#l00430
            if stream.side_data[i].type == lib.AV_PKT_DATA_DISPLAYMATRIX:
                side_data["DISPLAYMATRIX"] = lib.av_display_rotation_get(<const int32_t *>stream.side_data[i].data)

        return nb_side_data, side_data

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
    def average_rate(self):
        """
        The average frame rate of this video stream.

        This is calculated when the file is opened by looking at the first
        few frames and averaging their rate.

        :type: :class:`~fractions.Fraction` or ``None``


        """
        return avrational_to_fraction(&self.ptr.avg_frame_rate)

    @property
    def base_rate(self):
        """
        The base frame rate of this stream.

        This is calculated as the lowest framerate at which the timestamps of
        frames can be represented accurately. See :ffmpeg:`AVStream.r_frame_rate`
        for more.

        :type: :class:`~fractions.Fraction` or ``None``

        """
        return avrational_to_fraction(&self.ptr.r_frame_rate)

    @property
    def guessed_rate(self):
        """The guessed frame rate of this stream.

        This is a wrapper around :ffmpeg:`av_guess_frame_rate`, and uses multiple
        heuristics to decide what is "the" frame rate.

        :type: :class:`~fractions.Fraction` or ``None``

        """
        # The two NULL arguments aren't used in FFmpeg >= 4.0
        cdef lib.AVRational val = lib.av_guess_frame_rate(NULL, self.ptr, NULL)
        return avrational_to_fraction(&val)

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
        return self.metadata.get('language')

    @property
    def type(self):
        """
        The type of the stream.

        Examples: ``'audio'``, ``'video'``, ``'subtitle'``.

        :type: str
        """
        return lib.av_get_media_type_string(self.ptr.codecpar.codec_type)
