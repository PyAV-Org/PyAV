from libc.stdint cimport uint8_t, int64_t
from cpython cimport PyWeakref_NewRef

cimport libav as lib

from av.audio.stream cimport AudioStream
from av.packet cimport Packet
from av.subtitles.stream cimport SubtitleStream
from av.utils cimport err_check, avdict_to_dict, avrational_to_faction, to_avrational
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
        
        if self._container.ptr.iformat:

            # Find the codec.
            self._codec = lib.avcodec_find_decoder(self._codec_context.codec_id)
            if self._codec == NULL:
                raise RuntimeError('could not find %s codec' % self.type)
            
            # Open the codec.
            try:
                err_check(lib.avcodec_open2(self._codec_context, self._codec, &self._codec_options))
            except:
                # Signal that we don't need to close it.
                self._codec = NULL
                raise
        
        # Output container.
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
            self.codec.name or '<nocodec>',
            id(self),
        )

    property type:
        def __get__(self):
            # There is a convenient lib.av_get_media_type_string(x), but it
            # doesn't exist in libav.
            if self._codec_context.codec_type == lib.AVMEDIA_TYPE_VIDEO:
                return "video"
            elif self._codec_context.codec_type == lib.AVMEDIA_TYPE_AUDIO:
                return "audio"
            elif self._codec_context.codec_type == lib.AVMEDIA_TYPE_DATA:
                return "data"
            elif self._codec_context.codec_type == lib.AVMEDIA_TYPE_SUBTITLE:
                return "subtitle"
            elif self._codec_context.codec_type == lib.AVMEDIA_TYPE_ATTACHMENT:
                return "attachment"

    property name:
        def __get__(self):
            return bytes(self._codec.name) if self._codec else None

    property long_name:
        def __get__(self):
            return bytes(self._codec.long_name) if self._codec else None
    
    property index:
        def __get__(self): return self._stream.index


    property time_base:
        def __get__(self): return avrational_to_faction(&self._stream.time_base)

    property rate:
        def __get__(self): 
            if self._codec_context:
                return self._codec_context.ticks_per_frame * avrational_to_faction(&self._codec_context.time_base)

    property start_time:
        def __get__(self): return self._stream.start_time
    property duration:
        def __get__(self): return self._stream.duration

    property frames:
        def __get__(self): return self._stream.nb_frames
    

    property bit_rate:
        def __get__(self):
            return self._codec_context.bit_rate if self._codec_context else None
        def __set__(self, int value):
            self._codec_context.bit_rate = value
            
    property bit_rate_tolerance:
        def __get__(self):
            return self._codec_context.bit_rate_tolerance if self._codec_context else None
        def __set__(self, int value):
            self._codec_context.bit_rate_tolerance = value
            


    cpdef decode(self, Packet packet):

        cdef Frame frame
        cdef unsigned int frames_decoded = 0
        cdef int data_consumed = 0
        cdef list frames = []

        cdef uint8_t *original_data = packet.struct.data
        cdef int      original_size = packet.struct.size

        while packet.struct.size > 0:

            frame = self._decode_one(&packet.struct, &data_consumed)
            if not data_consumed:
                raise RuntimeError('no data consumed from packet')
            if packet.struct.data:
                packet.struct.data += data_consumed
            packet.struct.size -= data_consumed

            if frame:
                frames_decoded += 1
                self._setup_frame(frame)
                frames.append(frame)

        # Restore the packet.
        packet.struct.data = original_data
        packet.struct.size = original_size

        # Some codecs will cause frames to be buffered up in the decoding process.
        # These codecs should have a CODEC CAP_DELAY capability set.
        # This sends a special packet with data set to NULL and size set to 0
        # This tells the Packet Object that its the last packet    
        if frames_decoded:
            while True:
                # Create a new NULL packet for every frame we try to pull out.
                packet = Packet()
                frame = self._decode_one(&packet.struct, &data_consumed)
                if frame:
                    self._setup_frame(frame)
                    frames.append(frame)
                else:
                    break

        return frames
    
    cdef _setup_frame(self, Frame frame):
        frame.ptr.pts = lib.av_frame_get_best_effort_timestamp(frame.ptr)
        frame.time_base = self._stream.time_base
        frame.index = self._codec_context.frame_number - 1

    cdef Frame _decode_one(self, lib.AVPacket *packet, int *data_consumed):
        raise NotImplementedError('base stream cannot decode packets')

