from libc.stdint cimport uint8_t, int64_t
from libc.string cimport memcpy
from cpython cimport PyWeakref_NewRef

cimport libav as lib

from av.audio.stream cimport AudioStream
from av.packet cimport Packet
from av.subtitles.stream cimport SubtitleStream
from av.utils cimport err_check, avdict_to_dict, avrational_to_faction, to_avrational, media_type_to_string
from av.video.stream cimport VideoStream


cdef object _cinit_bypass_sentinel = object()


cdef Stream build_stream(Container container, lib.AVStream *c_stream):
    """Build an av.Stream for an existing AVStream.

    The AVStream MUST be fully constructed and ready for use before this is
    called.

    """
    
    # This better be the right one...
    assert container.proxy.ptr.streams[c_stream.index] == c_stream

    cdef Stream py_stream

    if c_stream.codec.codec_type == lib.AVMEDIA_TYPE_VIDEO:
        py_stream = VideoStream.__new__(VideoStream, _cinit_bypass_sentinel)
    elif c_stream.codec.codec_type == lib.AVMEDIA_TYPE_AUDIO:
        py_stream = AudioStream.__new__(AudioStream, _cinit_bypass_sentinel)
    elif c_stream.codec.codec_type == lib.AVMEDIA_TYPE_SUBTITLE:
        py_stream = SubtitleStream.__new__(SubtitleStream, _cinit_bypass_sentinel)
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
        
        self.metadata = avdict_to_dict(stream.metadata)
        
        # This is an input container!
        if self._container.ptr.iformat:

            # Find the codec.
            self._codec = lib.avcodec_find_decoder(self._codec_context.codec_id)
            if self._codec == NULL:
                return
            
            # Open the codec.
            try:
                err_check(lib.avcodec_open2(self._codec_context, self._codec, &self._codec_options))
            except:
                # Signal that we don't need to close it.
                self._codec = NULL
                raise
            
        # This is an output container!
        else:
            self._codec = self._codec_context.codec

    def __dealloc__(self):
        if self._codec:
            lib.avcodec_close(self._codec_context)
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

    property id:
        def __get__(self): return self._stream.id

    property type:
        def __get__(self): return media_type_to_string(self._codec_context.codec_type)

    property name:
        def __get__(self):
            return self._codec.name if self._codec else None

    property long_name:
        def __get__(self):
            return self._codec.long_name if self._codec else None
    
    property profile:
        def __get__(self):
            if self._codec and lib.av_get_profile_name(self._codec, self._codec_context.profile):
                return lib.av_get_profile_name(self._codec, self._codec_context.profile)
            else:
                return None

    property index:
        def __get__(self): return self._stream.index

    property time_base:
        def __get__(self): return avrational_to_faction(&self._stream.time_base)

    property rate:
        def __get__(self):
            if self._codec_context:
                return self._codec_context.ticks_per_frame * avrational_to_faction(&self._codec_context.time_base)
    
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

    property bit_rate:
        def __get__(self):
            return self._codec_context.bit_rate if self._codec_context and self._codec_context.bit_rate > 0 else None
        def __set__(self, int value):
            self._codec_context.bit_rate = value

    property max_bit_rate:
        def __get__(self):
            if self._codec_context and self._codec_context.rc_max_rate > 0:
                return self._codec_context.rc_max_rate
            else:
                return None
            
    property bit_rate_tolerance:
        def __get__(self):
            return self._codec_context.bit_rate_tolerance if self._codec_context else None
        def __set__(self, int value):
            self._codec_context.bit_rate_tolerance = value

    property language:
        def __get__(self):
            return self.metadata.get('language')

    # TODO: Does it conceptually make sense that this is on streams, instead
    # of on the container?
    property thread_count:
        def __get__(self):
            return self._codec_context.thread_count
        def __set__(self, int value):
            self._codec_context.thread_count = value

    cpdef decode(self, Packet packet, int count=0):
        """Decode a list of :class:`.Frame` from the given :class:`.Packet`.

        If the packet is None, the buffers will be flushed. This is useful if
        you do not want the library to automatically re-order frames for you
        (if they are encoded with a codec that has B-frames).

        """

        if packet is None:
            raise TypeError('packet must not be None')

        if not self._codec:
            raise ValueError('cannot decode unknown codec')

        cdef int data_consumed = 0
        cdef list decoded_objs = []

        cdef uint8_t *original_data = packet.struct.data
        cdef int      original_size = packet.struct.size

        cdef bint is_flushing = not (packet.struct.data and packet.struct.size)

        # Keep decoding while there is data.
        while is_flushing or packet.struct.size > 0:

            if is_flushing:
                packet.struct.data = NULL
                packet.struct.size = 0

            decoded = self._decode_one(&packet.struct, &data_consumed)
            packet.struct.data += data_consumed
            packet.struct.size -= data_consumed

            if decoded:

                if isinstance(decoded, Frame):
                    self._setup_frame(decoded)
                decoded_objs.append(decoded)

                # Sometimes we will error if we try to flush the stream
                # (e.g. MJPEG webcam streams), and so we must be able to
                # bail after the first, even though buffers may build up.
                if count and len(decoded_objs) >= count:
                    break

            # Sometimes there are no frames, and no data is consumed, and this
            # is ok. However, no more frames are going to be pulled out of here.
            # (It is possible for data to not be consumed as long as there are
            # frames, e.g. during flushing.)
            elif not data_consumed:
                break

        # Restore the packet.
        packet.struct.data = original_data
        packet.struct.size = original_size

        return decoded_objs
    
    def seek(self, timestamp, mode='time', backward=True, any_frame=False):
        """
        Seek to the keyframe at timestamp.
        """
        if isinstance(timestamp, float):
            self._container.seek(-1, <long>(timestamp * lib.AV_TIME_BASE), mode, backward, any_frame)
        else:
            self._container.seek(self._stream.index, timestamp, mode, backward, any_frame)
 
    cdef _setup_frame(self, Frame frame):
        # This PTS handling looks a little nuts, however it really seems like it
        # is the way to go. The PTS from a packet is the correct one while
        # decoding, and it is copied to pkt_pts during creation of a frame.
        frame.ptr.pts = frame.ptr.pkt_pts
        frame.time_base = self._stream.time_base
        frame.index = self._codec_context.frame_number - 1

    cdef _decode_one(self, lib.AVPacket *packet, int *data_consumed):
        raise NotImplementedError('base stream cannot decode packets')

