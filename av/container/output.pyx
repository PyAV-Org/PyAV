import logging
import os

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

    def add_stream(self, codec_name=None, object rate=None, Stream template=None, options=None, **kwargs):
        """add_stream(codec_name, rate=None)

        Create a new stream, and return it.

        :param str codec_name: The name of a codec.
        :param rate: The frame rate for video, and sample rate for audio.
            Examples for video include ``24``, ``23.976``, and
            ``Fraction(30000,1001)``. Examples for audio include ``48000``
            and ``44100``.
        :param template: Copy codec from another :class:`~av.stream.Stream` instance.
        :param dict options: Stream options.
        :param \\**kwargs: Set attributes of the stream.
        :returns: The new :class:`~av.stream.Stream`.

        """

        if (codec_name is None and template is None) or (codec_name is not None and template is not None):
            raise ValueError("needs one of codec_name or template")

        cdef const lib.AVCodec *codec
        cdef Codec codec_obj

        if codec_name is not None:
            codec_obj = codec_name if isinstance(codec_name, Codec) else Codec(codec_name, "w")
        else:
            if not template.codec_context:
                raise ValueError("template has no codec context")
            codec_obj = template.codec_context.codec
        codec = codec_obj.ptr

        # Assert that this format supports the requested codec.
        if not lib.avformat_query_codec(self.ptr.oformat, codec.id, lib.FF_COMPLIANCE_NORMAL):
            raise ValueError(
                f"{self.format.name!r} format does not support {codec_name!r} codec"
            )

        # Create new stream in the AVFormatContext, set AVCodecContext values.
        lib.avformat_new_stream(self.ptr, codec)
        cdef lib.AVStream *stream = self.ptr.streams[self.ptr.nb_streams - 1]
        cdef lib.AVCodecContext *codec_context = lib.avcodec_alloc_context3(codec)

        # Copy from the template.
        if template is not None:
            err_check(lib.avcodec_parameters_to_context(codec_context, template.ptr.codecpar))
            # Reset the codec tag assuming we are remuxing.
            codec_context.codec_tag = 0

        # Now lets set some more sane video defaults
        elif codec.type == lib.AVMEDIA_TYPE_VIDEO:
            codec_context.pix_fmt = lib.AV_PIX_FMT_YUV420P
            codec_context.width = 640
            codec_context.height = 480
            codec_context.bit_rate = 1024000
            codec_context.bit_rate_tolerance = 128000
            codec_context.ticks_per_frame = 1
            to_avrational(rate or 24, &codec_context.framerate)

            stream.avg_frame_rate = codec_context.framerate
            stream.time_base = codec_context.time_base

        # Some sane audio defaults
        elif codec.type == lib.AVMEDIA_TYPE_AUDIO:
            codec_context.sample_fmt = codec.sample_fmts[0]
            codec_context.bit_rate = 128000
            codec_context.bit_rate_tolerance = 32000
            codec_context.sample_rate = rate or 48000
            codec_context.channels = 2
            codec_context.channel_layout = lib.AV_CH_LAYOUT_STEREO

        # Some formats want stream headers to be separate
        if self.ptr.oformat.flags & lib.AVFMT_GLOBALHEADER:
            codec_context.flags |= lib.AV_CODEC_FLAG_GLOBAL_HEADER

        # Initialise stream codec parameters to populate the codec type.
        #
        # Subsequent changes to the codec context will be applied just before
        # encoding starts in `start_encoding()`.
        err_check(lib.avcodec_parameters_from_context(stream.codecpar, codec_context))

        # Construct the user-land stream
        cdef CodecContext py_codec_context = wrap_codec_context(codec_context, codec)
        cdef Stream py_stream = wrap_stream(self, stream, py_codec_context)
        self.streams.add_stream(py_stream)

        if options:
            py_stream.options.update(options)

        for k, v in kwargs.items():
            setattr(py_stream, k, v)

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
        self.err_check(lib.avformat_write_header(
            self.ptr,
            &options.ptr
        ))

        # Track option usage...
        for k in all_options:
            if k not in options:
                used_options.add(k)
        # ... and warn if any weren't used.
        unused_options = {k: v for k, v in self.options.items() if k not in used_options}
        if unused_options:
            log.warning("Some options were not used: %s" % unused_options)

        self._started = True

    def close(self):
        for stream in self.streams:
            if stream.codec_context:
                stream.codec_context.close(strict=False)

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
