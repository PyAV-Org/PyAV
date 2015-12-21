from fractions import Fraction

from av.container.streams cimport StreamContainer
from av.dictionary cimport _Dictionary
from av.packet cimport Packet
from av.stream cimport Stream, build_stream
from av.utils cimport err_check, dict_to_avdict


cdef class OutputContainer(Container):

    def __cinit__(self, *args, **kwargs):
        self.streams = StreamContainer()
        self.metadata = {}

    def __del__(self):
        self.close()

    cpdef add_stream(self, codec_name=None, object rate=None, Stream template=None):
        """add_stream(codec_name, rate=None)

        Create a new stream, and return it.

        :param str codec_name: The name of a codec.
        :param rate: The frame rate for video, and sample rate for audio.
            Examples for video include ``24``, ``23.976``, and
            ``Fraction(30000,1001)``. Examples for audio include ``48000``
            and ``44100``.
        :returns: The new :class:`~av.stream.Stream`.

        """
        
        if (codec_name is None and template is None) or (codec_name is not None and template is not None):
            raise ValueError('needs one of codec_name or template')

        cdef lib.AVCodec *codec
        cdef lib.AVCodecDescriptor *codec_descriptor

        if codec_name is not None:
            codec = lib.avcodec_find_encoder_by_name(codec_name)
            if not codec:
                codec_descriptor = lib.avcodec_descriptor_get_by_name(codec_name)
                if codec_descriptor:
                    codec = lib.avcodec_find_encoder(codec_descriptor.id)
            if not codec:
                raise ValueError("unknown encoding codec: %r" % codec_name)
        else:
            if not template._codec:
                raise ValueError("template has no codec")
            if not template._codec_context:
                raise ValueError("template has no codec context")
            codec = template._codec
        
        # Assert that this format supports the requested codec.
        if not lib.avformat_query_codec(
            self.proxy.ptr.oformat,
            codec.id,
            lib.FF_COMPLIANCE_NORMAL,
        ):
            raise ValueError("%r format does not support %r codec" % (self.format.name, codec_name))

        # Create new stream in the AVFormatContext, set AVCodecContext values.
        lib.avformat_new_stream(self.proxy.ptr, codec)
        cdef lib.AVStream *stream = self.proxy.ptr.streams[self.proxy.ptr.nb_streams - 1]
        cdef lib.AVCodecContext *codec_context = stream.codec # For readibility.
        lib.avcodec_get_context_defaults3(stream.codec, codec)
        stream.codec.codec = codec # Still have to manually set this though...

        # Copy from the template.
        if template is not None:
            lib.avcodec_copy_context(codec_context, template._codec_context)

        # Now lets set some more sane video defaults
        elif codec.type == lib.AVMEDIA_TYPE_VIDEO:
            codec_context.pix_fmt = lib.AV_PIX_FMT_YUV420P
            codec_context.width = 640
            codec_context.height = 480
            codec_context.bit_rate = 1024000
            codec_context.bit_rate_tolerance = 128000
            codec_context.ticks_per_frame = 1

            rate = Fraction(rate or 24)
            codec_context.time_base.num = rate.denominator
            codec_context.time_base.den = rate.numerator

            # TODO: Should this be inverted from the rate?
            stream.time_base.num = rate.denominator
            stream.time_base.den = rate.numerator

        # Some sane audio defaults
        elif codec.type == lib.AVMEDIA_TYPE_AUDIO:
            codec_context.sample_fmt = codec.sample_fmts[0]
            codec_context.bit_rate = 128000
            codec_context.bit_rate_tolerance = 32000
            codec_context.sample_rate = rate or 48000
            codec_context.channels = 2
            codec_context.channel_layout = lib.AV_CH_LAYOUT_STEREO

            # TODO: Should this be inverted from the rate?
            stream.time_base.num = 1
            stream.time_base.den = codec_context.sample_rate

        # Some formats want stream headers to be separate
        if self.proxy.ptr.oformat.flags & lib.AVFMT_GLOBALHEADER:
            codec_context.flags |= lib.CODEC_FLAG_GLOBAL_HEADER
        
        # Finally construct the user-land stream.
        cdef Stream py_stream = build_stream(self, stream)
        self.streams.add_stream(py_stream)
        return py_stream
    
    cpdef start_encoding(self):
        """Write the file header! Called automatically."""
        
        if self._started:
            return

        # Make sure all of the streams are open.
        cdef Stream stream
        cdef _Dictionary options
        for stream in self.streams:
            if not lib.avcodec_is_open(stream._codec_context):
                options = self.options.copy()
                self.proxy.err_check(lib.avcodec_open2(
                    stream._codec_context,
                    stream._codec,
                    # Our understanding is that there is little overlap bettween
                    # options for containers and streams, so we use the same dict.
                    # Possible TODO: expose per-stream options.
                    &options.ptr
                ))
            dict_to_avdict(&stream._stream.metadata, stream.metadata, clear=True)

        # Open the output file, if needed.
        # TODO: is the avformat_write_header in the right place here?
        cdef char *name = "" if self.proxy.file is not None else self.name

        if self.proxy.ptr.pb == NULL and not self.proxy.ptr.oformat.flags & lib.AVFMT_NOFILE:
            err_check(lib.avio_open(&self.proxy.ptr.pb, name, lib.AVIO_FLAG_WRITE))

        # Copy the metadata dict.
        dict_to_avdict(&self.proxy.ptr.metadata, self.metadata, clear=True)

        options = self.options.copy()
        self.proxy.err_check(lib.avformat_write_header(
            self.proxy.ptr, 
            &options.ptr
        ))

        self._started = True
            
    def close(self):

        if self._done:
            return
        if not self._started:
            raise RuntimeError('not started')
        if not self.proxy.ptr.pb:
            raise IOError("file not opened")
        
        self.proxy.err_check(lib.av_write_trailer(self.proxy.ptr))
        cdef Stream stream
        for stream in self.streams:
            lib.avcodec_close(stream._codec_context)
            
        if self.file is None and not self.proxy.ptr.oformat.flags & lib.AVFMT_NOFILE:
            lib.avio_closep(&self.proxy.ptr.pb)

        self._done = True
        
    def mux(self, Packet packet not None):
        self.start_encoding()
        self.proxy.err_check(lib.av_interleaved_write_frame(self.proxy.ptr, &packet.struct))


    