from cpython cimport PyWeakref_NewRef
from libc.stdint cimport int64_t, uint8_t
from libc.string cimport memcpy
cimport libav as lib

from av.codec.context cimport wrap_codec_context
from av.error cimport err_check
from av.packet cimport Packet
from av.utils cimport (
    avdict_to_dict,
    avrational_to_fraction,
    dict_to_avdict,
    to_avrational
)


cdef object _cinit_bypass_sentinel = object()


cdef Stream wrap_stream(Container container, lib.AVStream *c_stream):
    """Build an av.Stream for an existing AVStream.

    The AVStream MUST be fully constructed and ready for use before this is
    called.

    """

    # This better be the right one...
    assert container.ptr.streams[c_stream.index] == c_stream

    cdef Stream py_stream

    if c_stream.codec.codec_type == lib.AVMEDIA_TYPE_VIDEO:
        from av.video.stream import VideoStream
        py_stream = VideoStream.__new__(VideoStream, _cinit_bypass_sentinel)
    elif c_stream.codec.codec_type == lib.AVMEDIA_TYPE_AUDIO:
        from av.audio.stream import AudioStream
        py_stream = AudioStream.__new__(AudioStream, _cinit_bypass_sentinel)
    elif c_stream.codec.codec_type == lib.AVMEDIA_TYPE_SUBTITLE:
        from av.subtitles.stream import SubtitleStream
        py_stream = SubtitleStream.__new__(SubtitleStream, _cinit_bypass_sentinel)
    elif c_stream.codec.codec_type == lib.AVMEDIA_TYPE_DATA:
        from av.data.stream import DataStream
        py_stream = DataStream.__new__(DataStream, _cinit_bypass_sentinel)
    else:
        py_stream = Stream.__new__(Stream, _cinit_bypass_sentinel)

    py_stream._init(container, c_stream)
    return py_stream


cdef class Stream(object):
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
        raise RuntimeError('cannot manually instatiate Stream')

    cdef _init(self, Container container, lib.AVStream *stream):

        self.container = container
        self._stream = stream

        self._codec_context = stream.codec

        self.metadata = avdict_to_dict(
            stream.metadata,
            encoding=self.container.metadata_encoding,
            errors=self.container.metadata_errors,
        )

        # This is an input container!
        if self.container.ptr.iformat:

            # Find the codec.
            self._codec = lib.avcodec_find_decoder(self._codec_context.codec_id)
            if not self._codec:
                # TODO: Setup a dummy CodecContext.
                self.codec_context = None
                return

        # This is an output container!
        else:
            self._codec = self._codec_context.codec

        self.codec_context = wrap_codec_context(self._codec_context, self._codec, False)
        self.codec_context.stream_index = stream.index

    def __repr__(self):
        return '<av.%s #%d %s/%s at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.type or '<notype>',
            self.name or '<nocodec>',
            id(self),
        )

    def __getattr__(self, name):
        # avoid an infinite loop for unsupported codecs
        if self.codec_context is None:
            return

        try:
            return getattr(self.codec_context, name)
        except AttributeError:
            try:
                return getattr(self.codec_context.codec, name)
            except AttributeError:
                raise AttributeError(name)

    def __setattr__(self, name, value):
        if name == "id":
            self._set_id(value)
            return
        setattr(self.codec_context, name, value)
        if name == "time_base":
            self._set_time_base(value)

    cdef _finalize_for_output(self):

        dict_to_avdict(
            &self._stream.metadata, self.metadata,
            encoding=self.container.metadata_encoding,
            errors=self.container.metadata_errors,
        )

        if not self._stream.time_base.num:
            self._stream.time_base = self._codec_context.time_base

        # It prefers if we pass it parameters via this other object.
        # Lets just copy what we want.
        err_check(lib.avcodec_parameters_from_context(self._stream.codecpar, self._stream.codec))

    def encode(self, frame=None):
        """
        Encode an :class:`.AudioFrame` or :class:`.VideoFrame` and return a list
        of :class:`.Packet`.

        :return: :class:`list` of :class:`.Packet`.

        .. seealso:: This is mostly a passthrough to :meth:`.CodecContext.encode`.
        """
        packets = self.codec_context.encode(frame)
        cdef Packet packet
        for packet in packets:
            packet._stream = self
            packet.ptr.stream_index = self._stream.index
        return packets

    def decode(self, packet=None):
        """
        Decode a :class:`.Packet` and return a list of :class:`.AudioFrame`
        or :class:`.VideoFrame`.

        :return: :class:`list` of :class:`.Frame` subclasses.

        .. seealso:: This is mostly a passthrough to :meth:`.CodecContext.decode`.
        """
        return self.codec_context.decode(packet)

    property id:
        """
        The format-specific ID of this stream.

        :type: int

        """
        def __get__(self):
            return self._stream.id

    cdef _set_id(self, value):
        """
        Setter used by __setattr__ for the id property.
        """
        if value is None:
            self._stream.id = 0
        else:
            self._stream.id = value

    property profile:
        """
        The profile of this stream.

        :type: str
        """
        def __get__(self):
            if self._codec and lib.av_get_profile_name(self._codec, self._codec_context.profile):
                return lib.av_get_profile_name(self._codec, self._codec_context.profile)
            else:
                return None

    property index:
        """
        The index of this stream in its :class:`.Container`.

        :type: int
        """
        def __get__(self): return self._stream.index

    property time_base:
        """
        The unit of time (in fractional seconds) in which timestamps are expressed.

        :type: :class:`~fractions.Fraction` or ``None``

        """
        def __get__(self):
            return avrational_to_fraction(&self._stream.time_base)

    cdef _set_time_base(self, value):
        """
        Setter used by __setattr__ for the time_base property.
        """
        to_avrational(value, &self._stream.time_base)

    property average_rate:
        """
        The average frame rate of this video stream.

        This is calculated when the file is opened by looking at the first
        few frames and averaging their rate.

        :type: :class:`~fractions.Fraction` or ``None``


        """
        def __get__(self):
            return avrational_to_fraction(&self._stream.avg_frame_rate)

    property base_rate:
        """
        The base frame rate of this stream.

        This is calculated as the lowest framerate at which the timestamps of
        frames can be represented accurately. See :ffmpeg:`AVStream.r_frame_rate`
        for more.

        :type: :class:`~fractions.Fraction` or ``None``

        """
        def __get__(self):
            return avrational_to_fraction(&self._stream.r_frame_rate)

    property guessed_rate:
        """The guessed frame rate of this stream.

        This is a wrapper around :ffmpeg:`av_guess_frame_rate`, and uses multiple
        heuristics to decide what is "the" frame rate.

        :type: :class:`~fractions.Fraction` or ``None``

        """
        def __get__(self):
            # The two NULL arguments aren't used in FFmpeg >= 4.0
            cdef lib.AVRational val = lib.av_guess_frame_rate(NULL, self._stream, NULL)
            return avrational_to_fraction(&val)

    property start_time:
        """
        The presentation timestamp in :attr:`time_base` units of the first
        frame in this stream.

        :type: :class:`int` or ``None``
        """
        def __get__(self):
            if self._stream.start_time != lib.AV_NOPTS_VALUE:
                return self._stream.start_time

    property duration:
        """
        The duration of this stream in :attr:`time_base` units.

        :type: :class:`int` or ``None``

        """
        def __get__(self):
            if self._stream.duration != lib.AV_NOPTS_VALUE:
                return self._stream.duration

    property frames:
        """
        The number of frames this stream contains.

        Returns ``0`` if it is not known.

        :type: int
        """
        def __get__(self): return self._stream.nb_frames

    property language:
        """
        The language of the stream.

        :type: :class:``str`` or ``None``
        """
        def __get__(self):
            return self.metadata.get('language')

    @property
    def type(self):
        """
        The type of the stream.

        Examples: ``'audio'``, ``'video'``, ``'subtitle'``.

        :type: str
        """
        return lib.av_get_media_type_string(self._codec_context.codec_type)
