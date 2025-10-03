import os
from fractions import Fraction

import cython
from cython.cimports import libav as lib
from cython.cimports.av.codec.codec import Codec
from cython.cimports.av.codec.context import CodecContext, wrap_codec_context
from cython.cimports.av.container.streams import StreamContainer
from cython.cimports.av.dictionary import _Dictionary
from cython.cimports.av.error import err_check
from cython.cimports.av.packet import Packet
from cython.cimports.av.stream import Stream, wrap_stream
from cython.cimports.av.utils import dict_to_avdict, to_avrational

from av.dictionary import Dictionary


@cython.cfunc
def close_output(self: OutputContainer):
    self.streams = StreamContainer()
    if self._started and not self._done:
        # We must only ever call av_write_trailer *once*, otherwise we get a
        # segmentation fault. Therefore no matter whether it succeeds or not
        # we must absolutely set self._done.
        try:
            self.err_check(lib.av_write_trailer(self.ptr))
        finally:
            if self.file is None and not (self.ptr.oformat.flags & lib.AVFMT_NOFILE):
                lib.avio_closep(cython.address(self.ptr.pb))
            self._done = True


@cython.cclass
class OutputContainer(Container):
    def __cinit__(self, *args, **kwargs):
        self.streams = StreamContainer()
        self.metadata = {}
        with cython.nogil:
            self.packet_ptr = lib.av_packet_alloc()

    def __dealloc__(self):
        close_output(self)
        with cython.nogil:
            lib.av_packet_free(cython.address(self.packet_ptr))

    def add_stream(self, codec_name, rate=None, options: dict | None = None, **kwargs):
        """add_stream(codec_name, rate=None)

        Creates a new stream from a codec name and returns it.
        Supports video, audio, and subtitle streams.

        :param codec_name: The name of a codec.
        :type codec_name: str
        :param dict options: Stream options.
        :param \\**kwargs: Set attributes for the stream.
        :rtype: The new :class:`~av.stream.Stream`.

        """

        codec_obj: Codec = Codec(codec_name, "w")
        codec: cython.pointer[cython.const[lib.AVCodec]] = codec_obj.ptr

        # Assert that this format supports the requested codec.
        if not lib.avformat_query_codec(
            self.ptr.oformat, codec.id, lib.FF_COMPLIANCE_NORMAL
        ):
            raise ValueError(
                f"{self.format.name!r} format does not support {codec_obj.name!r} codec"
            )

        # Create new stream in the AVFormatContext, set AVCodecContext values.
        stream: cython.pointer[lib.AVStream] = lib.avformat_new_stream(self.ptr, codec)
        ctx: cython.pointer[lib.AVCodecContext] = lib.avcodec_alloc_context3(codec)

        # Now lets set some more sane video defaults
        if codec.type == lib.AVMEDIA_TYPE_VIDEO:
            ctx.pix_fmt = lib.AV_PIX_FMT_YUV420P
            ctx.width = kwargs.pop("width", 640)
            ctx.height = kwargs.pop("height", 480)
            ctx.bit_rate = kwargs.pop("bit_rate", 0)
            ctx.bit_rate_tolerance = kwargs.pop("bit_rate_tolerance", 128000)
            try:
                to_avrational(kwargs.pop("time_base"), cython.address(ctx.time_base))
            except KeyError:
                pass
            to_avrational(rate or 24, cython.address(ctx.framerate))

            stream.avg_frame_rate = ctx.framerate
            stream.time_base = ctx.time_base

        # Some sane audio defaults
        elif codec.type == lib.AVMEDIA_TYPE_AUDIO:
            ctx.sample_fmt = codec.sample_fmts[0]
            ctx.bit_rate = kwargs.pop("bit_rate", 0)
            ctx.bit_rate_tolerance = kwargs.pop("bit_rate_tolerance", 32000)
            try:
                to_avrational(kwargs.pop("time_base"), cython.address(ctx.time_base))
            except KeyError:
                pass

            if rate is None:
                ctx.sample_rate = 48000
            elif type(rate) is int:
                ctx.sample_rate = rate
            else:
                raise TypeError("audio stream `rate` must be: int | None")
            stream.time_base = ctx.time_base
            lib.av_channel_layout_default(cython.address(ctx.ch_layout), 2)

        # Some formats want stream headers to be separate
        if self.ptr.oformat.flags & lib.AVFMT_GLOBALHEADER:
            ctx.flags |= lib.AV_CODEC_FLAG_GLOBAL_HEADER

        # Initialise stream codec parameters to populate the codec type.
        #
        # Subsequent changes to the codec context will be applied just before
        # encoding starts in `start_encoding()`.
        err_check(lib.avcodec_parameters_from_context(stream.codecpar, ctx))

        # Construct the user-land stream
        py_codec_context: CodecContext = wrap_codec_context(ctx, codec, None)
        py_stream: Stream = wrap_stream(self, stream, py_codec_context)
        self.streams.add_stream(py_stream)

        if options:
            py_stream.options.update(options)

        for k, v in kwargs.items():
            setattr(py_stream, k, v)

        return py_stream

    def add_stream_from_template(
        self, template: Stream, opaque: bool | None = None, **kwargs
    ):
        """
        Creates a new stream from a template. Supports video, audio, subtitle, data and attachment streams.

        :param template: Copy codec from another :class:`~av.stream.Stream` instance.
        :param opaque: If True, copy opaque data from the template's codec context.
        :param \\**kwargs: Set attributes for the stream.
        :rtype: The new :class:`~av.stream.Stream`.
        """
        if opaque is None:
            opaque = template.type != "video"

        if template.codec_context is None:
            return self._add_stream_without_codec_from_template(template, **kwargs)

        codec_obj: Codec
        if opaque:  # Copy ctx from template.
            codec_obj = template.codec_context.codec
        else:  # Construct new codec object.
            codec_obj = Codec(template.codec_context.codec.name, "w")

        codec: cython.pointer[cython.const[lib.AVCodec]] = codec_obj.ptr

        # Assert that this format supports the requested codec.
        if not lib.avformat_query_codec(
            self.ptr.oformat, codec.id, lib.FF_COMPLIANCE_NORMAL
        ):
            raise ValueError(
                f"{self.format.name!r} format does not support {codec_obj.name!r} codec"
            )

        # Create new stream in the AVFormatContext, set AVCodecContext values.
        stream: cython.pointer[lib.AVStream] = lib.avformat_new_stream(self.ptr, codec)
        ctx: cython.pointer[lib.AVCodecContext] = lib.avcodec_alloc_context3(codec)

        err_check(lib.avcodec_parameters_to_context(ctx, template.ptr.codecpar))
        # Reset the codec tag assuming we are remuxing.
        ctx.codec_tag = 0

        # Some formats want stream headers to be separate
        if self.ptr.oformat.flags & lib.AVFMT_GLOBALHEADER:
            ctx.flags |= lib.AV_CODEC_FLAG_GLOBAL_HEADER

        # Copy flags If we're creating a new codec object. This fixes some muxing issues.
        # Overwriting `ctx.flags |= lib.AV_CODEC_FLAG_GLOBAL_HEADER` is intentional.
        if not opaque:
            ctx.flags = template.codec_context.flags

        # Initialize stream codec parameters to populate the codec type. Subsequent changes to
        # the codec context will be applied just before encoding starts in `start_encoding()`.
        err_check(lib.avcodec_parameters_from_context(stream.codecpar, ctx))

        # Construct the user-land stream
        py_codec_context: CodecContext = wrap_codec_context(ctx, codec, None)
        py_stream: Stream = wrap_stream(self, stream, py_codec_context)
        self.streams.add_stream(py_stream)

        for k, v in kwargs.items():
            setattr(py_stream, k, v)

        return py_stream

    def _add_stream_without_codec_from_template(
        self, template: Stream, **kwargs
    ) -> Stream:
        codec_type: cython.int = template.ptr.codecpar.codec_type
        if codec_type not in {lib.AVMEDIA_TYPE_ATTACHMENT, lib.AVMEDIA_TYPE_DATA}:
            raise ValueError(
                f"template stream of type {template.type} has no codec context"
            )

        stream: cython.pointer[lib.AVStream] = lib.avformat_new_stream(
            self.ptr, cython.NULL
        )
        if stream == cython.NULL:
            raise MemoryError("Could not allocate stream")

        err_check(lib.avcodec_parameters_copy(stream.codecpar, template.ptr.codecpar))

        # Mirror basic properties that are not derived from a codec context.
        stream.time_base = template.ptr.time_base
        stream.start_time = template.ptr.start_time
        stream.duration = template.ptr.duration
        stream.disposition = template.ptr.disposition

        py_stream: Stream = wrap_stream(self, stream, None)
        self.streams.add_stream(py_stream)

        py_stream.metadata = dict(template.metadata)

        for k, v in kwargs.items():
            setattr(py_stream, k, v)

        return py_stream

    def add_attachment(self, name: str, mimetype: str, data: bytes):
        """
        Create an attachment stream and embed its payload into the container header.

        - Only supported by formats that support attachments (e.g. Matroska).
        - No per-packet muxing is required; attachments are written at header time.
        """
        # Create stream with no codec (attachments are codec-less).
        stream: cython.pointer[lib.AVStream] = lib.avformat_new_stream(
            self.ptr, cython.NULL
        )
        if stream == cython.NULL:
            raise MemoryError("Could not allocate stream")

        stream.codecpar.codec_type = lib.AVMEDIA_TYPE_ATTACHMENT
        stream.codecpar.codec_id = lib.AV_CODEC_ID_NONE

        # Allocate and copy payload into codecpar.extradata.
        payload_size: cython.size_t = len(data)
        if payload_size:
            buf = cython.cast(cython.p_uchar, lib.av_malloc(payload_size + 1))
            if buf == cython.NULL:
                raise MemoryError("Could not allocate attachment data")
            # Copy bytes.
            for i in range(payload_size):
                buf[i] = data[i]
            buf[payload_size] = 0
            stream.codecpar.extradata = cython.cast(cython.p_uchar, buf)
            stream.codecpar.extradata_size = payload_size

        # Wrap as user-land stream.
        meta_ptr = cython.address(stream.metadata)
        err_check(lib.av_dict_set(meta_ptr, b"filename", name.encode(), 0))
        mime_bytes = mimetype.encode()
        err_check(lib.av_dict_set(meta_ptr, b"mimetype", mime_bytes, 0))

        py_stream: Stream = wrap_stream(self, stream, None)
        self.streams.add_stream(py_stream)
        return py_stream

    def add_data_stream(self, codec_name=None, options: dict | None = None):
        """add_data_stream(codec_name=None)

        Creates a new data stream and returns it.

        :param codec_name: Optional name of the data codec (e.g. 'klv')
        :type codec_name: str | None
        :param dict options: Stream options.
        :rtype: The new :class:`~av.data.stream.DataStream`.
        """
        codec: cython.pointer[cython.const[lib.AVCodec]] = cython.NULL

        if codec_name is not None:
            codec = lib.avcodec_find_encoder_by_name(codec_name.encode())
            if codec == cython.NULL:
                raise ValueError(f"Unknown data codec: {codec_name}")

            # Assert that this format supports the requested codec
            if not lib.avformat_query_codec(
                self.ptr.oformat, codec.id, lib.FF_COMPLIANCE_NORMAL
            ):
                raise ValueError(
                    f"{self.format.name!r} format does not support {codec_name!r} codec"
                )

        # Create new stream in the AVFormatContext
        stream: cython.pointer[lib.AVStream] = lib.avformat_new_stream(self.ptr, codec)
        if stream == cython.NULL:
            raise MemoryError("Could not allocate stream")

        # Set up codec context if we have a codec
        ctx: cython.pointer[lib.AVCodecContext] = cython.NULL
        if codec != cython.NULL:
            ctx = lib.avcodec_alloc_context3(codec)
            if ctx == cython.NULL:
                raise MemoryError("Could not allocate codec context")

            # Some formats want stream headers to be separate
            if self.ptr.oformat.flags & lib.AVFMT_GLOBALHEADER:
                ctx.flags |= lib.AV_CODEC_FLAG_GLOBAL_HEADER

            # Initialize stream codec parameters
            err_check(lib.avcodec_parameters_from_context(stream.codecpar, ctx))
        else:
            # For raw data streams, just set the codec type
            stream.codecpar.codec_type = lib.AVMEDIA_TYPE_DATA

        # Construct the user-land stream
        py_codec_context: CodecContext | None = None
        if ctx != cython.NULL:
            py_codec_context = wrap_codec_context(ctx, codec, None)

        py_stream: Stream = wrap_stream(self, stream, py_codec_context)
        self.streams.add_stream(py_stream)

        if options:
            py_stream.options.update(options)

        return py_stream

    @cython.ccall
    def start_encoding(self):
        """Write the file header! Called automatically."""
        if self._started:
            return

        # TODO: This does NOT handle options coming from 3 sources.
        # This is only a rough approximation of what would be cool to do.
        used_options: set = set()
        stream: Stream

        # Finalize and open all streams.
        for stream in self.streams:
            ctx = stream.codec_context
            # Skip codec context handling for streams without codecs (e.g. data/attachments).
            if ctx is None:
                if stream.type not in {"data", "attachment"}:
                    raise ValueError(f"Stream {stream.index} has no codec context")
            else:
                if not ctx.is_open:
                    for k, v in self.options.items():
                        ctx.options.setdefault(k, v)
                    ctx.open()

                    # Track option consumption.
                    for k in self.options:
                        if k not in ctx.options:
                            used_options.add(k)

            stream._finalize_for_output()

        # Open the output file, if needed.
        name_obj: bytes = os.fsencode(self.name if self.file is None else "")
        name: cython.p_char = name_obj
        if self.ptr.pb == cython.NULL and not self.ptr.oformat.flags & lib.AVFMT_NOFILE:
            err_check(
                lib.avio_open(cython.address(self.ptr.pb), name, lib.AVIO_FLAG_WRITE)
            )

        # Copy the metadata dict.
        dict_to_avdict(
            cython.address(self.ptr.metadata),
            self.metadata,
            encoding=self.metadata_encoding,
            errors=self.metadata_errors,
        )

        all_options: _Dictionary = Dictionary(self.options, self.container_options)
        options: _Dictionary = all_options.copy()
        self.err_check(lib.avformat_write_header(self.ptr, cython.address(options.ptr)))

        # Track option usage...
        for k in all_options:
            if k not in options:
                used_options.add(k)

        # ... and warn if any weren't used.
        unused_options = {
            k: v for k, v in self.options.items() if k not in used_options
        }
        if unused_options:
            import logging

            log = logging.getLogger(__name__)
            log.warning("Some options were not used: %s" % unused_options)

        self._started = True

    @property
    def supported_codecs(self):
        """
        Returns a set of all codecs this format supports.
        """
        result: set = set()
        codec: cython.pointer[cython.const[lib.AVCodec]] = cython.NULL
        opaque: cython.p_void = cython.NULL

        while True:
            codec = lib.av_codec_iterate(cython.address(opaque))
            if codec == cython.NULL:
                break

            if (
                lib.avformat_query_codec(
                    self.ptr.oformat, codec.id, lib.FF_COMPLIANCE_NORMAL
                )
                == 1
            ):
                result.add(codec.name)

        return result

    @property
    def default_video_codec(self):
        """
        Returns the default video codec this container recommends.
        """
        return lib.avcodec_get_name(self.format.optr.video_codec)

    @property
    def default_audio_codec(self):
        """
        Returns the default audio codec this container recommends.
        """
        return lib.avcodec_get_name(self.format.optr.audio_codec)

    @property
    def default_subtitle_codec(self):
        """
        Returns the default subtitle codec this container recommends.
        """
        return lib.avcodec_get_name(self.format.optr.subtitle_codec)

    def close(self):
        close_output(self)

    def mux(self, packets):
        # We accept either a Packet, or a sequence of packets. This should smooth out
        # the transition to the new encode API which returns a sequence of packets.
        if isinstance(packets, Packet):
            self.mux_one(packets)
        else:
            for packet in packets:
                self.mux_one(packet)

    def mux_one(self, packet: Packet):
        self.start_encoding()

        # Assert the packet is in stream time.
        if (
            packet.ptr.stream_index < 0
            or cython.cast(cython.uint, packet.ptr.stream_index) >= self.ptr.nb_streams
        ):
            raise ValueError("Bad Packet stream_index.")

        stream: cython.pointer[lib.AVStream] = self.ptr.streams[packet.ptr.stream_index]
        packet._rebase_time(stream.time_base)

        # Make another reference to the packet, as `av_interleaved_write_frame()`
        # takes ownership of the reference.
        self.err_check(lib.av_packet_ref(self.packet_ptr, packet.ptr))

        with cython.nogil:
            ret: cython.int = lib.av_interleaved_write_frame(self.ptr, self.packet_ptr)
        self.err_check(ret)
