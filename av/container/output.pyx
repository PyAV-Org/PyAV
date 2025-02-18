import logging
import os
from fractions import Fraction

cimport libav as lib

from av.codec.codec cimport Codec
from av.codec.context cimport CodecContext, wrap_codec_context
from av.container.streams cimport StreamContainer
from av.dictionary cimport _Dictionary
from av.error cimport err_check
from av.packet cimport Packet
from av.stream cimport Stream, wrap_stream
from av.utils cimport dict_to_avdict, to_avrational

from av.dictionary import Dictionary

log = logging.getLogger(__name__)


cdef close_output(OutputContainer self):
    self.streams = StreamContainer()
    if self._started and not self._done:
        # We must only ever call av_write_trailer *once*, otherwise we get a
        # segmentation fault. Therefore no matter whether it succeeds or not
        # we must absolutely set self._done.
        try:
            self.err_check(lib.av_write_trailer(self.ptr))
        finally:
            if self.file is None and not (self.ptr.oformat.flags & lib.AVFMT_NOFILE):
                lib.avio_closep(&self.ptr.pb)
            self._done = True


cdef class OutputContainer(Container):
    def __cinit__(self, *args, **kwargs):
        self.streams = StreamContainer()
        self.metadata = {}
        with nogil:
            self.packet_ptr = lib.av_packet_alloc()

    def __dealloc__(self):
        close_output(self)
        with nogil:
            lib.av_packet_free(&self.packet_ptr)

    def add_stream(self, codec_name, rate=None, dict options=None, **kwargs):
        """add_stream(codec_name, rate=None)

        Creates a new stream from a codec name and returns it.
        Supports video, audio, and subtitle streams.

        :param codec_name: The name of a codec.
        :type codec_name: str
        :param dict options: Stream options.
        :param \\**kwargs: Set attributes for the stream.
        :rtype: The new :class:`~av.stream.Stream`.

        """

        cdef Codec codec_obj = Codec(codec_name, "w")
        cdef const lib.AVCodec *codec = codec_obj.ptr

        # Assert that this format supports the requested codec.
        if not lib.avformat_query_codec(self.ptr.oformat, codec.id, lib.FF_COMPLIANCE_NORMAL):
            raise ValueError(
                f"{self.format.name!r} format does not support {codec_obj.name!r} codec"
            )

        # Create new stream in the AVFormatContext, set AVCodecContext values.
        cdef lib.AVStream *stream = lib.avformat_new_stream(self.ptr, codec)
        cdef lib.AVCodecContext *codec_context = lib.avcodec_alloc_context3(codec)

        # Now lets set some more sane video defaults
        if codec.type == lib.AVMEDIA_TYPE_VIDEO:
            codec_context.pix_fmt = lib.AV_PIX_FMT_YUV420P
            codec_context.width = kwargs.pop("width", 640)
            codec_context.height = kwargs.pop("height", 480)
            codec_context.bit_rate = kwargs.pop("bit_rate", 0)
            codec_context.bit_rate_tolerance = kwargs.pop("bit_rate_tolerance", 128000)
            try:
                to_avrational(kwargs.pop("time_base"), &codec_context.time_base)
            except KeyError:
                pass
            to_avrational(rate or 24, &codec_context.framerate)

            stream.avg_frame_rate = codec_context.framerate
            stream.time_base = codec_context.time_base

        # Some sane audio defaults
        elif codec.type == lib.AVMEDIA_TYPE_AUDIO:
            codec_context.sample_fmt = codec.sample_fmts[0]
            codec_context.bit_rate = kwargs.pop("bit_rate", 0)
            codec_context.bit_rate_tolerance = kwargs.pop("bit_rate_tolerance", 32000)
            try:
                to_avrational(kwargs.pop("time_base"), &codec_context.time_base)
            except KeyError:
                pass

            if rate is None:
                codec_context.sample_rate = 48000
            elif type(rate) is int:
                codec_context.sample_rate = rate
            else:
                raise TypeError("audio stream `rate` must be: int | None")
            stream.time_base = codec_context.time_base
            lib.av_channel_layout_default(&codec_context.ch_layout, 2)

        # Some formats want stream headers to be separate
        if self.ptr.oformat.flags & lib.AVFMT_GLOBALHEADER:
            codec_context.flags |= lib.AV_CODEC_FLAG_GLOBAL_HEADER

        # Initialise stream codec parameters to populate the codec type.
        #
        # Subsequent changes to the codec context will be applied just before
        # encoding starts in `start_encoding()`.
        err_check(lib.avcodec_parameters_from_context(stream.codecpar, codec_context))

        # Construct the user-land stream
        cdef CodecContext py_codec_context = wrap_codec_context(codec_context, codec, None)
        cdef Stream py_stream = wrap_stream(self, stream, py_codec_context)
        self.streams.add_stream(py_stream)

        if options:
            py_stream.options.update(options)

        for k, v in kwargs.items():
            setattr(py_stream, k, v)

        return py_stream

    def add_stream_from_template(self, Stream template not None, opaque=None, **kwargs):
        """
        Creates a new stream from a template. Supports video, audio, and subtitle streams.

        :param template: Copy codec from another :class:`~av.stream.Stream` instance.
        :param opaque: If True, copy opaque data from the template's codec context.
        :param \\**kwargs: Set attributes for the stream.
        :rtype: The new :class:`~av.stream.Stream`.
        """
        cdef const lib.AVCodec *codec
        cdef Codec codec_obj

        if opaque is None:
            opaque = template.type != "video"

        if opaque:  # Copy ctx from template.
            codec_obj = template.codec_context.codec
        else:   # Construct new codec object.
            codec_obj = Codec(template.codec_context.codec.name, "w")
        codec = codec_obj.ptr

        # Assert that this format supports the requested codec.
        if not lib.avformat_query_codec(self.ptr.oformat, codec.id, lib.FF_COMPLIANCE_NORMAL):
            raise ValueError(
                f"{self.format.name!r} format does not support {codec_obj.name!r} codec"
            )

        # Create new stream in the AVFormatContext, set AVCodecContext values.
        cdef lib.AVStream *stream = lib.avformat_new_stream(self.ptr, codec)
        cdef lib.AVCodecContext *codec_context = lib.avcodec_alloc_context3(codec)

        err_check(lib.avcodec_parameters_to_context(codec_context, template.ptr.codecpar))
        # Reset the codec tag assuming we are remuxing.
        codec_context.codec_tag = 0

        # Some formats want stream headers to be separate
        if self.ptr.oformat.flags & lib.AVFMT_GLOBALHEADER:
            codec_context.flags |= lib.AV_CODEC_FLAG_GLOBAL_HEADER

        # Initialize stream codec parameters to populate the codec type. Subsequent changes to
        # the codec context will be applied just before encoding starts in `start_encoding()`.
        err_check(lib.avcodec_parameters_from_context(stream.codecpar, codec_context))

        # Construct the user-land stream
        cdef CodecContext py_codec_context = wrap_codec_context(codec_context, codec, None)
        cdef Stream py_stream = wrap_stream(self, stream, py_codec_context)
        self.streams.add_stream(py_stream)

        for k, v in kwargs.items():
            setattr(py_stream, k, v)

        return py_stream


    def add_data_stream(self, codec_name=None, dict options=None):
        """add_data_stream(codec_name=None)

        Creates a new data stream and returns it.

        :param codec_name: Optional name of the data codec (e.g. 'klv')
        :type codec_name: str | None
        :param dict options: Stream options.
        :rtype: The new :class:`~av.data.stream.DataStream`.
        """
        cdef const lib.AVCodec *codec = NULL

        if codec_name is not None:
            codec = lib.avcodec_find_encoder_by_name(codec_name.encode())
            if codec == NULL:
                raise ValueError(f"Unknown data codec: {codec_name}")

            # Assert that this format supports the requested codec
            if not lib.avformat_query_codec(self.ptr.oformat, codec.id, lib.FF_COMPLIANCE_NORMAL):
                raise ValueError(
                    f"{self.format.name!r} format does not support {codec_name!r} codec"
                )

        # Create new stream in the AVFormatContext
        cdef lib.AVStream *stream = lib.avformat_new_stream(self.ptr, codec)
        if stream == NULL:
            raise MemoryError("Could not allocate stream")

        # Set up codec context if we have a codec
        cdef lib.AVCodecContext *codec_context = NULL
        if codec != NULL:
            codec_context = lib.avcodec_alloc_context3(codec)
            if codec_context == NULL:
                raise MemoryError("Could not allocate codec context")

            # Some formats want stream headers to be separate
            if self.ptr.oformat.flags & lib.AVFMT_GLOBALHEADER:
                codec_context.flags |= lib.AV_CODEC_FLAG_GLOBAL_HEADER

            # Initialize stream codec parameters
            err_check(lib.avcodec_parameters_from_context(stream.codecpar, codec_context))
        else:
            # For raw data streams, just set the codec type
            stream.codecpar.codec_type = lib.AVMEDIA_TYPE_DATA

        # Construct the user-land stream
        cdef CodecContext py_codec_context = None
        if codec_context != NULL:
            py_codec_context = wrap_codec_context(codec_context, codec, None)

        cdef Stream py_stream = wrap_stream(self, stream, py_codec_context)
        self.streams.add_stream(py_stream)

        if options:
            py_stream.options.update(options)

        return py_stream

    cpdef start_encoding(self):
        """Write the file header! Called automatically."""

        if self._started:
            return

        # TODO: This does NOT handle options coming from 3 sources.
        # This is only a rough approximation of what would be cool to do.
        used_options = set()

        # Finalize and open all streams.
        cdef Stream stream
        for stream in self.streams:
            ctx = stream.codec_context
            # Skip codec context handling for data streams without codecs
            if ctx is None:
                if stream.type != "data":
                    raise ValueError(f"Stream {stream.index} has no codec context")
                continue

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
        cdef bytes name_obj = os.fsencode(self.name if self.file is None else "")
        cdef char *name = name_obj
        if self.ptr.pb == NULL and not self.ptr.oformat.flags & lib.AVFMT_NOFILE:
            err_check(lib.avio_open(&self.ptr.pb, name, lib.AVIO_FLAG_WRITE))

        # Copy the metadata dict.
        dict_to_avdict(
            &self.ptr.metadata, self.metadata,
            encoding=self.metadata_encoding,
            errors=self.metadata_errors
        )

        cdef _Dictionary all_options = Dictionary(self.options, self.container_options)
        cdef _Dictionary options = all_options.copy()
        self.err_check(lib.avformat_write_header(self.ptr, &options.ptr))

        # Track option usage...
        for k in all_options:
            if k not in options:
                used_options.add(k)
        # ... and warn if any weren't used.
        unused_options = {k: v for k, v in self.options.items() if k not in used_options}
        if unused_options:
            log.warning("Some options were not used: %s" % unused_options)

        self._started = True

    @property
    def supported_codecs(self):
        """
        Returns a set of all codecs this format supports.
        """
        result = set()
        cdef const lib.AVCodec *codec = NULL
        cdef void *opaque = NULL

        while True:
            codec = lib.av_codec_iterate(&opaque)
            if codec == NULL:
                break

            if lib.avformat_query_codec(self.ptr.oformat, codec.id, lib.FF_COMPLIANCE_NORMAL) == 1:
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
        # We accept either a Packet, or a sequence of packets. This should
        # smooth out the transition to the new encode API which returns a
        # sequence of packets.
        if isinstance(packets, Packet):
            self.mux_one(packets)
        else:
            for packet in packets:
                self.mux_one(packet)

    def mux_one(self, Packet packet not None):
        self.start_encoding()

        # Assert the packet is in stream time.
        if packet.ptr.stream_index < 0 or <unsigned int>packet.ptr.stream_index >= self.ptr.nb_streams:
            raise ValueError("Bad Packet stream_index.")
        cdef lib.AVStream *stream = self.ptr.streams[packet.ptr.stream_index]
        packet._rebase_time(stream.time_base)

        # Make another reference to the packet, as av_interleaved_write_frame
        # takes ownership of the reference.
        self.err_check(lib.av_packet_ref(self.packet_ptr, packet.ptr))

        cdef int ret
        with nogil:
            ret = lib.av_interleaved_write_frame(self.ptr, self.packet_ptr)
        self.err_check(ret)
