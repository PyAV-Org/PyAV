from libc.stdlib cimport malloc, free

from av.container.streams cimport StreamContainer
from av.dictionary cimport _Dictionary
from av.packet cimport Packet
from av.stream cimport Stream, wrap_stream
from av.utils cimport err_check, avdict_to_dict

from av.utils import AVError # not cimport
from av.dictionary import Dictionary


cdef class InputContainer(Container):

    def __cinit__(self, *args, **kwargs):

        cdef int i

        # If we have either the global `options`, or a `stream_options`, prepare
        # a mashup of those options for each stream.
        cdef lib.AVDictionary **c_options = NULL
        cdef _Dictionary base_dict, stream_dict
        if self.options or self.stream_options:
            base_dict = Dictionary(self.options)
            c_options = <lib.AVDictionary**>malloc(self.proxy.ptr.nb_streams * sizeof(void*))
            for i in range(self.proxy.ptr.nb_streams):
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
                self.proxy.ptr,
                c_options
            )
        self.proxy.err_check(ret)

        # Cleanup all of our options.
        if c_options:
            for i in range(self.proxy.ptr.nb_streams):
                lib.av_dict_free(&c_options[i])
            free(c_options)

        self.streams = StreamContainer()
        for i in range(self.proxy.ptr.nb_streams):
            self.streams.add_stream(wrap_stream(self, self.proxy.ptr.streams[i]))

        self.metadata = avdict_to_dict(self.proxy.ptr.metadata, self.metadata_encoding, self.metadata_errors)

    property start_time:
        def __get__(self): return self.proxy.ptr.start_time

    property duration:
        def __get__(self): return self.proxy.ptr.duration

    property bit_rate:
        def __get__(self): return self.proxy.ptr.bit_rate

    property size:
        def __get__(self): return lib.avio_size(self.proxy.ptr.pb)

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

        cdef bint *include_stream = <bint*>malloc(self.proxy.ptr.nb_streams * sizeof(bint))
        if include_stream == NULL:
            raise MemoryError()

        cdef int i
        cdef Packet packet
        cdef int ret

        try:

            for i in range(self.proxy.ptr.nb_streams):
                include_stream[i] = False
            for stream in streams:
                i = stream.index
                if i >= self.proxy.ptr.nb_streams:
                    raise ValueError('stream index %d out of range' % i)
                include_stream[i] = True

            while True:

                packet = Packet()
                try:
                    with nogil:
                        ret = lib.av_read_frame(self.proxy.ptr, &packet.struct)
                    self.proxy.err_check(ret)
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
            for i in range(self.proxy.ptr.nb_streams):
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
        id(kwargs) # Avoid Cython bug; see demux().
        for packet in self.demux(*args, **kwargs):
            for frame in packet.decode():
                yield frame

    def seek(self, offset, whence='time', backward=True, any_frame=False):
        """Seek to a (key)frame nearsest to the given timestamp.

        :param int offset: Location to seek to. Interpretation depends on ``whence``.
        :param str whence: One of ``'time'``, ``'frame'``, or ``'byte'``
        :param bool backward: If there is not a (key)frame at the given offset,
            look backwards for it.
        :param bool any_frame: Seek to any frame, not just a keyframe.

        ``whence`` has the following meanings:

        - ``'time'``: ``offset`` is in ``av.TIME_BASE``.
        - ``'frame'``: ``offset`` is a frame index
        - ``'byte'``: ``offset`` is the byte location in the file to seek to.

        .. warning:: Not all formats support all options.

        """
        self.proxy.seek(-1, offset, whence, backward, any_frame)
