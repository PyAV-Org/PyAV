from libc.stdint cimport int64_t
from libc.stdlib cimport malloc, free

from av.container.streams cimport StreamContainer
from av.dictionary cimport _Dictionary
from av.packet cimport Packet
from av.stream cimport Stream, wrap_stream
from av.utils cimport err_check, avdict_to_dict

from av.utils import AVError  # not cimport
from av.dictionary import Dictionary


cdef close_input(InputContainer self):
    if self.input_was_opened:
        with nogil:
            lib.avformat_close_input(&self.ptr)
        self.input_was_opened = False


cdef class InputContainer(Container):

    def __cinit__(self, *args, **kwargs):

        cdef unsigned int i

        # If we have either the global `options`, or a `stream_options`, prepare
        # a mashup of those options for each stream.
        cdef lib.AVDictionary **c_options = NULL
        cdef _Dictionary base_dict, stream_dict
        if self.options or self.stream_options:
            base_dict = Dictionary(self.options)
            c_options = <lib.AVDictionary**>malloc(self.ptr.nb_streams * sizeof(void*))
            for i in range(self.ptr.nb_streams):
                c_options[i] = NULL
                if i < len(self.stream_options) and self.stream_options:
                    stream_dict = base_dict.copy()
                    stream_dict.update(self.stream_options[i])
                    lib.av_dict_copy(&c_options[i], stream_dict.ptr, 0)
                else:
                    lib.av_dict_copy(&c_options[i], base_dict.ptr, 0)

        with nogil:
            # This peeks are the first few frames to:
            #   - set stream.disposition from codec.audio_service_type (not exposed);
            #   - set stream.codec.bits_per_coded_sample;
            #   - set stream.duration;
            #   - set stream.start_time;
            #   - set stream.r_frame_rate to average value;
            #   - open and closes codecs with the options provided.
            ret = lib.avformat_find_stream_info(
                self.ptr,
                c_options
            )
        self.err_check(ret)

        # Cleanup all of our options.
        if c_options:
            for i in range(self.ptr.nb_streams):
                lib.av_dict_free(&c_options[i])
            free(c_options)

        self.streams = StreamContainer()
        for i in range(self.ptr.nb_streams):
            self.streams.add_stream(wrap_stream(self, self.ptr.streams[i]))

        self.metadata = avdict_to_dict(self.ptr.metadata, self.metadata_encoding, self.metadata_errors)

    def __dealloc__(self):
        close_input(self)

    property start_time:
        def __get__(self): return self.ptr.start_time

    property duration:
        def __get__(self): return self.ptr.duration

    property bit_rate:
        def __get__(self): return self.ptr.bit_rate

    property size:
        def __get__(self): return lib.avio_size(self.ptr.pb)

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

        # For whatever reason, Cython does not like us directly passing kwargs
        # from one method to another. Without kwargs, it ends up passing a
        # NULL reference, which segfaults. So we force it to do something with it.
        # This is likely a bug in Cython; see https://github.com/cython/cython/issues/2166
        # (and others).
        id(kwargs)

        streams = self.streams.get(*args, **kwargs)

        cdef bint *include_stream = <bint*>malloc(self.ptr.nb_streams * sizeof(bint))
        if include_stream == NULL:
            raise MemoryError()

        cdef unsigned int i
        cdef Packet packet
        cdef int ret

        try:

            for i in range(self.ptr.nb_streams):
                include_stream[i] = False
            for stream in streams:
                i = stream.index
                if i >= self.ptr.nb_streams:
                    raise ValueError('stream index %d out of range' % i)
                include_stream[i] = True

            while True:

                packet = Packet()
                try:
                    with nogil:
                        ret = lib.av_read_frame(self.ptr, &packet.struct)
                    self.err_check(ret)
                except AVError:
                    break

                if include_stream[packet.struct.stream_index]:
                    # If AVFMTCTX_NOHEADER is set in ctx_flags, then new streams
                    # may also appear in av_read_frame().
                    # http://ffmpeg.org/doxygen/trunk/structAVFormatContext.html
                    # TODO: find better way to handle this
                    if packet.struct.stream_index < len(self.streams):
                        packet._stream = self.streams[packet.struct.stream_index]
                        # Keep track of this so that remuxing is easier.
                        packet._time_base = packet._stream._stream.time_base
                        yield packet

            # Flush!
            for i in range(self.ptr.nb_streams):
                if include_stream[i]:
                    packet = Packet()
                    packet._stream = self.streams[i]
                    packet._time_base = packet._stream._stream.time_base
                    yield packet

        finally:
            free(include_stream)

    def decode(self, *args, **kwargs):
        """decode(streams=None, video=None, audio=None, subtitles=None, data=None)

        Yields a series of :class:`.Frame` from the given set of streams::

            for frame in container.decode():
                # Do something with `frame`.

        .. seealso:: :meth:`.StreamContainer.get` for the interpretation of
            the arguments.

        """
        id(kwargs)  # Avoid Cython bug; see demux().
        for packet in self.demux(*args, **kwargs):
            for frame in packet.decode():
                yield frame

    def seek(self, offset, str whence='time', bint backward=True, bint any_frame=False, Stream stream=None):
        """Seek to a (key)frame nearsest to the given timestamp.

        :param int offset: Location to seek to. Interpretation depends on ``whence``.
        :param str whence: One of ``'time'``, ``'frame'``, or ``'byte'``
        :param bool backward: If there is not a (key)frame at the given offset,
            look backwards for it.
        :param bool any_frame: Seek to any frame, not just a keyframe.
        :param Stream stream: The stream who's ``time_base`` the ``offset`` is in.

        ``whence`` has the following meanings:

        - ``'time'``: ``offset`` is in ``stream.time_base`` if ``stream`` else ``av.time_base``.
        - ``'frame'``: ``offset`` is a frame index
        - ``'byte'``: ``offset`` is the byte location in the file to seek to.

        .. warning:: Not all formats support all options, and may fail silently.

        """

        # We used to take floats here and assume they were in seconds. This
        # was super confusing, so lets go in the complete opposite direction.
        if not isinstance(offset, (int, long)):
            raise TypeError('Container.seek only accepts integer offset.', type(offset))
        cdef int64_t c_offset = offset

        cdef int flags = 0
        cdef int ret

        if whence == 'frame':
            flags |= lib.AVSEEK_FLAG_FRAME
        elif whence == 'byte':
            flags |= lib.AVSEEK_FLAG_BYTE
        elif whence != 'time':
            raise ValueError("whence must be one of 'frame', 'byte', or 'time'.", whence)

        if backward:
            flags |= lib.AVSEEK_FLAG_BACKWARD

        if any_frame:
            flags |= lib.AVSEEK_FLAG_ANY

        cdef int stream_index = stream.index if stream else -1
        with nogil:
            ret = lib.av_seek_frame(self.ptr, stream_index, c_offset, flags)
        err_check(ret)

        self.flush_buffers()

    cdef flush_buffers(self):
        cdef unsigned int i
        cdef lib.AVStream *stream

        with nogil:
            for i in range(self.ptr.nb_streams):
                stream = self.ptr.streams[i]
                if stream.codec and stream.codec.codec and stream.codec.codec_id != lib.AV_CODEC_ID_NONE:
                    lib.avcodec_flush_buffers(stream.codec)
