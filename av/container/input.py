import cython
from cython.cimports.av.codec.context import CodecContext, wrap_codec_context
from cython.cimports.av.container.streams import StreamContainer
from cython.cimports.av.dictionary import _Dictionary
from cython.cimports.av.error import err_check
from cython.cimports.av.packet import Packet
from cython.cimports.av.stream import Stream, wrap_stream
from cython.cimports.av.utils import avdict_to_dict
from cython.cimports.libc.stdint import int64_t
from cython.cimports.libc.stdlib import free, malloc

from av.dictionary import Dictionary


@cython.cfunc
def close_input(self: InputContainer):
    self.streams = StreamContainer()
    if self.input_was_opened:
        with cython.nogil:
            # This causes `self.ptr` to be set to NULL.
            lib.avformat_close_input(cython.address(self.ptr))
        self.input_was_opened = False


@cython.cclass
class InputContainer(Container):
    def __cinit__(self, *args, **kwargs):
        py_codec_context: CodecContext
        i: cython.uint
        stream: cython.pointer[lib.AVStream]
        codec: cython.pointer[lib.AVCodec]
        codec_context: cython.pointer[lib.AVCodecContext]

        # If we have either the global `options`, or a `stream_options`, prepare
        # a mashup of those options for each stream.
        c_options: cython.pointer[cython.pointer[lib.AVDictionary]] = cython.NULL
        base_dict: _Dictionary
        stream_dict: _Dictionary
        if self.options or self.stream_options:
            base_dict = Dictionary(self.options)
            c_options = cython.cast(
                cython.pointer[cython.pointer[lib.AVDictionary]],
                malloc(self.ptr.nb_streams * cython.sizeof(cython.p_void)),
            )
            for i in range(self.ptr.nb_streams):
                c_options[i] = cython.NULL
                if i < len(self.stream_options) and self.stream_options:
                    stream_dict = base_dict.copy()
                    stream_dict.update(self.stream_options[i])
                    lib.av_dict_copy(cython.address(c_options[i]), stream_dict.ptr, 0)
                else:
                    lib.av_dict_copy(cython.address(c_options[i]), base_dict.ptr, 0)

        self.set_timeout(self.open_timeout)
        self.start_timeout()
        with cython.nogil:
            # This peeks are the first few frames to:
            #   - set stream.disposition from codec.audio_service_type (not exposed);
            #   - set stream.codec.bits_per_coded_sample;
            #   - set stream.duration;
            #   - set stream.start_time;
            #   - set stream.r_frame_rate to average value;
            #   - open and closes codecs with the options provided.
            ret = lib.avformat_find_stream_info(self.ptr, c_options)
        self.set_timeout(None)
        self.err_check(ret)

        # Clean up all of our options.
        if c_options:
            for i in range(self.ptr.nb_streams):
                lib.av_dict_free(cython.address(c_options[i]))
            free(c_options)

        at_least_one_accelerated_context = False

        self.streams = StreamContainer()
        for i in range(self.ptr.nb_streams):
            stream = self.ptr.streams[i]
            codec = lib.avcodec_find_decoder(stream.codecpar.codec_id)
            if codec:
                # allocate and initialize decoder
                codec_context = lib.avcodec_alloc_context3(codec)
                err_check(
                    lib.avcodec_parameters_to_context(codec_context, stream.codecpar)
                )
                codec_context.pkt_timebase = stream.time_base
                py_codec_context = wrap_codec_context(
                    codec_context, codec, self.hwaccel
                )
                if py_codec_context.is_hwaccel:
                    at_least_one_accelerated_context = True
            else:
                # no decoder is available
                py_codec_context = None
            self.streams.add_stream(wrap_stream(self, stream, py_codec_context))

        if (
            self.hwaccel
            and not self.hwaccel.allow_software_fallback
            and not at_least_one_accelerated_context
        ):
            raise RuntimeError(
                "Hardware accelerated decode requested but no stream is compatible"
            )

        self.metadata = avdict_to_dict(
            self.ptr.metadata, self.metadata_encoding, self.metadata_errors
        )

    def __dealloc__(self):
        close_input(self)

    @property
    def start_time(self):
        self._assert_open()
        if self.ptr.start_time != lib.AV_NOPTS_VALUE:
            return self.ptr.start_time

    @property
    def duration(self):
        self._assert_open()
        if self.ptr.duration != lib.AV_NOPTS_VALUE:
            return self.ptr.duration

    @property
    def bit_rate(self):
        self._assert_open()
        return self.ptr.bit_rate

    @property
    def size(self):
        self._assert_open()
        return lib.avio_size(self.ptr.pb)

    def close(self):
        close_input(self)

    def demux(self, *args, **kwargs):
        """demux(streams=None, video=None, audio=None, subtitles=None, data=None)

        Yields a series of :class:`.Packet` from the given set of :class:`.Stream`::

            for packet in container.demux():
                # Do something with `packet`, often:
                for frame in packet.decode():
                    # Do something with `frame`.

        .. seealso:: :meth:`.StreamContainer.get` for the interpretation of
            the arguments.

        .. note:: The last packets are dummy packets that when decoded will flush the buffers.

        """
        self._assert_open()

        # For whatever reason, Cython does not like us directly passing kwargs
        # from one method to another. Without kwargs, it ends up passing a
        # NULL reference, which segfaults. So we force it to do something with it.
        # This is a bug in Cython; see https://github.com/cython/cython/issues/2166
        id(kwargs)

        streams = self.streams.get(*args, **kwargs)
        include_stream: cython.pointer[cython.bint] = cython.cast(
            cython.pointer[cython.bint],
            malloc(self.ptr.nb_streams * cython.sizeof(bint)),
        )
        if include_stream == cython.NULL:
            raise MemoryError()

        i: cython.uint
        packet: Packet
        ret: cython.int

        self.set_timeout(self.read_timeout)
        try:
            for i in range(self.ptr.nb_streams):
                include_stream[i] = False
            for stream in streams:
                i = stream.index
                if i >= self.ptr.nb_streams:
                    raise ValueError(f"stream index {i} out of range")
                include_stream[i] = True

            while True:
                packet = Packet()
                try:
                    self.start_timeout()
                    with cython.nogil:
                        ret = lib.av_read_frame(self.ptr, packet.ptr)
                    self.err_check(ret)
                except EOFError:
                    break

                if include_stream[packet.ptr.stream_index]:
                    # If AVFMTCTX_NOHEADER is set in ctx_flags, then new streams
                    # may also appear in av_read_frame().
                    # http://ffmpeg.org/doxygen/trunk/structAVFormatContext.html
                    # TODO: find better way to handle this
                    if packet.ptr.stream_index < len(self.streams):
                        packet._stream = self.streams[packet.ptr.stream_index]
                        # Keep track of this so that remuxing is easier.
                        packet.ptr.time_base = packet._stream.ptr.time_base
                        yield packet

            # Flush!
            for i in range(self.ptr.nb_streams):
                if include_stream[i]:
                    packet = Packet()
                    packet._stream = self.streams[i]
                    packet.ptr.time_base = packet._stream.ptr.time_base
                    yield packet

        finally:
            self.set_timeout(None)
            free(include_stream)

    def decode(self, *args, **kwargs):
        """decode(streams=None, video=None, audio=None, subtitles=None, data=None)

        Yields a series of :class:`.Frame` from the given set of streams::

            for frame in container.decode():
                # Do something with `frame`.

        .. seealso:: :meth:`.StreamContainer.get` for the interpretation of
            the arguments.

        """
        self._assert_open()
        id(kwargs)  # Avoid Cython bug; see demux().
        for packet in self.demux(*args, **kwargs):
            for frame in packet.decode():
                yield frame

    def seek(
        self,
        offset,
        *,
        backward: cython.bint = True,
        any_frame: cython.bint = False,
        stream: Stream | None = None,
        unsupported_frame_offset: cython.bint = False,
        unsupported_byte_offset: cython.bint = False,
    ):
        """seek(offset, *, backward=True, any_frame=False, stream=None)

        Seek to a (key)frame nearsest to the given timestamp.

        :param int offset: Time to seek to, expressed in``stream.time_base`` if ``stream``
            is given, otherwise in :data:`av.time_base`.
        :param bool backward: If there is not a (key)frame at the given offset,
            look backwards for it.
        :param bool any_frame: Seek to any frame, not just a keyframe.
        :param Stream stream: The stream who's ``time_base`` the ``offset`` is in.

        :param bool unsupported_frame_offset: ``offset`` is a frame
            index instead of a time; not supported by any known format.
        :param bool unsupported_byte_offset: ``offset`` is a byte
            location in the file; not supported by any known format.

        After seeking, packets that you demux should correspond (roughly) to
        the position you requested.

        In most cases, the defaults of ``backwards = True`` and ``any_frame = False``
        are the best course of action, followed by you demuxing/decoding to
        the position that you want. This is because to properly decode video frames
        you need to start from the previous keyframe.

        .. seealso:: :ffmpeg:`avformat_seek_file` for discussion of the flags.

        """
        self._assert_open()

        if not isinstance(offset, int):
            raise TypeError("Container.seek only accepts integer offset.", type(offset))

        c_offset: int64_t = offset
        flags: cython.int = 0
        ret: cython.int

        if backward:
            flags |= lib.AVSEEK_FLAG_BACKWARD
        if any_frame:
            flags |= lib.AVSEEK_FLAG_ANY

        # If someone really wants (and to experiment), expose these.
        if unsupported_frame_offset:
            flags |= lib.AVSEEK_FLAG_FRAME
        if unsupported_byte_offset:
            flags |= lib.AVSEEK_FLAG_BYTE

        stream_index: cython.int = stream.index if stream else -1
        with cython.nogil:
            ret = lib.av_seek_frame(self.ptr, stream_index, c_offset, flags)
        err_check(ret)

        self.flush_buffers()

    @cython.cfunc
    def flush_buffers(self):
        self._assert_open()

        stream: Stream
        codec_context: CodecContext

        for stream in self.streams:
            codec_context = stream.codec_context
            if codec_context:
                codec_context.flush_buffers()
