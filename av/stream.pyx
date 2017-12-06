from libc.stdint cimport uint8_t, int64_t
from libc.string cimport memcpy
from cpython cimport PyWeakref_NewRef

cimport libav as lib


from av.codec.context cimport wrap_codec_context
from av.packet cimport Packet
from av.utils cimport err_check, dict_to_avdict, avdict_to_dict, avrational_to_faction, to_avrational, media_type_to_string



cdef object _cinit_bypass_sentinel = object()


cdef Stream wrap_stream(Container container, lib.AVStream *c_stream):
    """Build an av.Stream for an existing AVStream.

    The AVStream MUST be fully constructed and ready for use before this is
    called.

    """

    # This better be the right one...
    assert container.proxy.ptr.streams[c_stream.index] == c_stream

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

    def __cinit__(self, name):
        if name is _cinit_bypass_sentinel:
            return
        raise RuntimeError('cannot manually instatiate Stream')

    cdef _init(self, Container container, lib.AVStream *stream):

        self._container = container.proxy
        self._weak_container = PyWeakref_NewRef(container, None)
        self._stream = stream

        self._codec_context = stream.codec

        self.metadata = avdict_to_dict(stream.metadata,
            encoding=self._container.metadata_encoding,
            errors=self._container.metadata_errors,
        )

        # This is an input container!
        if self._container.ptr.iformat:

            # Find the codec.
            self._codec = lib.avcodec_find_decoder(self._codec_context.codec_id)
            if not self._codec:
                # TODO: Setup a dummy CodecContext.
                return

            # Open the codec.
            # TODO: Replace this with the call to codec_context.open() below,
            #       once we pass options to it.
            err_check(lib.avcodec_open2(self._codec_context, self._codec, &self._codec_options))

        # This is an output container!
        else:
            self._codec = self._codec_context.codec

        self.codec_context = wrap_codec_context(self._codec_context, self._codec, False)
        self.codec_context.stream_index = stream.index

        # if self._container.ptr.iformat:
            # self.codec_context.open(strict=False)

    def __dealloc__(self):
        if self._codec_options:
            lib.av_dict_free(&self._codec_options)

    def __repr__(self):
        return '<av.%s #%d %s/%s at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.type or '<notype>',
            self.name or '<nocodec>',
            id(self),
        )

    def __getattr__(self, name):
        try:
            return getattr(self.codec_context, name)
        except AttributeError:
            return

    def __setattr__(self, name, value):
        setattr(self.codec_context, name, value)

    cdef _finalize_for_output(self):
        dict_to_avdict(&self._stream.metadata, self.metadata,
            clear=True,
            encoding=self._container.metadata_encoding,
            errors=self._container.metadata_errors,
        )
        if not self._stream.time_base.num:
            self._stream.time_base = self._codec_context.time_base

    def encode(self, frame=None):
        packets = self.codec_context.encode(frame)
        cdef Packet packet
        for packet in packets:
            packet._stream = self
            packet.struct.stream_index = self._stream.index
        return packets

    def decode(self, packet=None, count=0):
        return self.codec_context.decode(packet, count)

    def seek(self, offset, whence='time', backward=True, any_frame=False):
        """seek(offset, whence='time', backward=True, any_frame=False)

        .. seealso:: :meth:`.InputContainer.seek` for documentation on parameters.
            The only difference is that ``offset`` will be interpreted in
            :attr:`.Stream.time_base` when ``whence == 'time'``.

        """
        self._container.seek(self._stream.index, offset, whence, backward, any_frame)

    property id:
        def __get__(self):
            return self._stream.id
        def __set__(self, v):
            if v is None:
                self._stream.id = 0
            else:
                self._stream.id = v

    property profile:
        def __get__(self):
            if self._codec and lib.av_get_profile_name(self._codec, self._codec_context.profile):
                return lib.av_get_profile_name(self._codec, self._codec_context.profile)
            else:
                return None

    property index:
        def __get__(self): return self._stream.index

    property time_base:
        def __get__(self):
            return avrational_to_faction(&self._stream.time_base)
        def __set__(self, value):
            to_avrational(value, &self._stream.time_base)

    property average_rate:
        def __get__(self):
            return avrational_to_faction(&self._stream.avg_frame_rate)

    property start_time:
        def __get__(self): return self._stream.start_time

    property duration:
        def __get__(self):
            if self._stream.duration == lib.AV_NOPTS_VALUE:
                return None
            return self._stream.duration

    property frames:
        def __get__(self): return self._stream.nb_frames

    property language:
        def __get__(self):
            return self.metadata.get('language')
