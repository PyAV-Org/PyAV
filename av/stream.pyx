from libc.stdint cimport uint8_t, int64_t
from libc.string cimport memcpy
from cpython cimport PyWeakref_NewRef

cimport libav as lib

from av.audio.stream cimport AudioStream
from av.packet cimport Packet
from av.subtitles.stream cimport SubtitleStream
from av.utils cimport err_check, avdict_to_dict, avrational_to_faction, to_avrational, media_type_to_string
from av.video.stream cimport VideoStream

from encode cimport Encoder
from decode cimport Decoder

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

        cdef CodecContext coder
        # This is an input container!
        if self._container.ptr.iformat:

            # Find the codec.
            self._codec = lib.avcodec_find_decoder(stream.codec.codec_id)
            if self._codec == NULL:
                return

            coder = Decoder.__new__(Decoder)
            coder.ptr = stream.codec
            coder.ptr.codec = self._codec
            coder.channels = coder.channels # small hack to set channel_layout
            coder._container = container.proxy
            coder.open()

        # This is an output container!
        else:
            coder = Encoder.__new__(Encoder)
            coder._container = container.proxy
            coder.ptr = stream.codec

            # use codec codec config by OutputContainer
            self._codec = stream.codec.codec

        self.coder = coder
        self._codec_context = coder.ptr

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

        cdef list decoded_objs = []
        cdef bint is_flushing = not (packet.struct.data and packet.struct.size)

        if is_flushing:
            for frame in self.coder.flush():
                if isinstance(frame, Frame):
                    self._setup_frame(frame)
                decoded_objs.append(frame)
        else:
            for frame in self.coder.decode(packet):
                if isinstance(frame, Frame):
                    self._setup_frame(frame)
                decoded_objs.append(frame)

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
        frame._time_base = self._stream.time_base
        frame.index = self._codec_context.frame_number - 1
