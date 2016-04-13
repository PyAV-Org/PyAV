from libc.stdlib cimport malloc, free

from av.container.streams cimport StreamContainer
from av.dictionary cimport _Dictionary
from av.packet cimport Packet
from av.stream cimport Stream, build_stream
from av.utils cimport err_check, avdict_to_dict

from av.utils import AVError # not cimport


cdef class InputContainer(Container):

    def __cinit__(self, *args, **kwargs):

        cdef _Dictionary options = self.options.copy()
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
                # Our understanding is that there is little overlap bettween
                # options for containers and streams, so we use the same dict.
                # FIXME: This expects per-stream options.
                &options.ptr
            )
        self.proxy.err_check(ret)

        self.streams = StreamContainer()
        cdef int i
        for i in range(self.proxy.ptr.nb_streams):
            self.streams.add_stream(build_stream(self, self.proxy.ptr.streams[i]))

        self.metadata = avdict_to_dict(self.proxy.ptr.metadata)

    property start_time:
        def __get__(self): return self.proxy.ptr.start_time

    property duration:
        def __get__(self): return self.proxy.ptr.duration

    property bit_rate:
        def __get__(self): return self.proxy.ptr.bit_rate

    property size:
        def __get__(self): return lib.avio_size(self.proxy.ptr.pb)

    def demux(self, *args, **kwargs):
        """demux(streams=None, video=None, audio=None, subtitles=None)

        Yields a series of :class:`.Packet` from the given set of :class:`.Stream`

        The last packets are dummy packets that when decoded will flush the buffers.

        """

        # For whatever reason, Cython does not like us directly passing kwargs
        # from one method to another. Without kwargs, it ends up passing a
        # NULL reference, which segfaults. So we force it to do something with it.
        # This is likely a bug in Cython.
        kwargs = kwargs or {}
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
                        packet.stream = self.streams[packet.struct.stream_index]
                        yield packet

            # Flush!
            for i in range(self.proxy.ptr.nb_streams):
                if include_stream[i]:
                    packet = Packet()
                    packet.stream = self.streams[i]
                    yield packet

        finally:
            free(include_stream)

    def decode(self, *args, **kwargs):
        for packet in self.demux(*args, **kwargs):
            for frame in packet.decode():
                yield frame

    def seek(self, timestamp, mode='time', backward=True, any_frame=False):
        """Seek to the keyframe at the given timestamp.

        :param int timestamp: time in AV_TIME_BASE units.
        :param str mode: one of ``"backward"``, ``"frame"``, ``"byte"``, or ``"any"``.

        """
        if isinstance(timestamp, float):
            timestamp = <long>(timestamp * lib.AV_TIME_BASE)
        self.proxy.seek(-1, timestamp, mode, backward, any_frame)
