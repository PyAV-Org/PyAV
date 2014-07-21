from libc.stdint cimport uint8_t, int64_t
from libc.string cimport memcpy
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
    elif c_stream.codec.codec_type == lib.AVMEDIA_TYPE_SUBTITLE:
        py_stream = SubtitleStream.__new__(SubtitleStream, _cinit_bypass_sentinel)
    else:
        py_stream = Stream.__new__(Stream, _cinit_bypass_sentinel)

    py_stream._init(container, c_stream)
    return py_stream

cdef int pyav_get_buffer(lib.AVCodecContext *ctx, lib.AVFrame *frame):
    
    # Get the buffer the way it would normally get it
    cdef int ret
    ret = lib.avcodec_default_get_buffer(ctx, frame)

    # Allocate a int64_t and copy the current pts stored in 
    # AVCodecContext.opaque, which is a pointer to Stream.packet_pts.
    # stream.packet_pts is set in the decode method of Stream.
    # this is done so the new AVFrame can store this pts of the first packet
    # needed to create it. This is need later for timing purposes see
    # http://dranger.com/ffmpeg/tutorial05.html. this is the done the same way but
    # we use AVCodecContext.opaque so we don't need a global variable.
    
    # Allocate a new int64_t to be stored in AVFrame
    cdef int64_t *pkt_pts = <int64_t*>lib.av_malloc(sizeof(int64_t))
    if not pkt_pts:
        return lib.AVERROR_NOMEM
    
    # Copy Packet pts
    memcpy(pkt_pts, ctx.opaque, sizeof(int64_t))
    
    # Assign AVFrame.opaque pointer to new PacketInfo
    frame.opaque = pkt_pts
    
    #return the result of avcodec_default_get_buffer
    return ret

cdef void pyav_release_buffer(lib.AVCodecContext *ctx, lib.AVFrame *frame):
    if frame:
        #Free AVFrame packet pts
        lib.av_freep(&frame.opaque)

    lib.avcodec_default_release_buffer(ctx, frame)
    
    
    
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
        self.packet_pts = lib.AV_NOPTS_VALUE
        
        if self._container.ptr.iformat:

            # Find the codec.
            self._codec = lib.avcodec_find_decoder(self._codec_context.codec_id)
            if self._codec == NULL:
                return
                #raise RuntimeError('could not find %s codec' % self.type)
            
            # Open the codec.
            try:
                err_check(lib.avcodec_open2(self._codec_context, self._codec, &self._codec_options))
            except:
                # Signal that we don't need to close it.
                self._codec = NULL
                raise
            
            self._codec_context.opaque = &self.packet_pts
            
            self._codec_context.get_buffer = pyav_get_buffer
            self._codec_context.release_buffer = pyav_release_buffer
            
            
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
            return self._codec_context.bit_rate if self._codec_context else None
        def __set__(self, int value):
            self._codec_context.bit_rate = value
            
    property bit_rate_tolerance:
        def __get__(self):
            return self._codec_context.bit_rate_tolerance if self._codec_context else None
        def __set__(self, int value):
            self._codec_context.bit_rate_tolerance = value
            


    cpdef decode(self, Packet packet):
    
        if not packet.struct.data:
            return self._flush_decoder_frames()

        cdef int data_consumed = 0
        cdef list frames = []
        
        cdef Frame frame

        cdef uint8_t *original_data = packet.struct.data
        cdef int      original_size = packet.struct.size
        
        cdef int64_t packet_dts = packet.struct.dts
        cdef int64_t * packet_pts
        
        self.packet_pts = packet.struct.pts

        while packet.struct.size > 0:

            frame = self._decode_one(&packet.struct, &data_consumed)
            if not data_consumed:
                raise RuntimeError('no data consumed from packet')
            if packet.struct.data:
                packet.struct.data += data_consumed
            packet.struct.size -= data_consumed

            if frame:

                self._setup_frame(frame)
                
                # According to http://dranger.com/ffmpeg/tutorial05.html
                # ffmpeg reorders the packets so that the DTS of the packet
                # being processed by avcodec_decode_video() will always be the same
                # as the PTS of the frame it returns.
                # And The PTS of frame is also equal to the PTS of the first
                # Packet needed to decode it
                
                # retrive packet pts from frame.ptr.opaque 
                packet_pts = <int64_t *> frame.ptr.opaque
                
                if packet_pts[0] != lib.AV_NOPTS_VALUE:
                    frame.ptr.pts = packet_pts[0] 
                
                elif packet_dts != lib.AV_NOPTS_VALUE:
                    frame.ptr.pts = packet_dts
                
                else:
                    frame.ptr.pts = lib.AV_NOPTS_VALUE             
                    
                frames.append(frame)

        # Restore the packet.
        packet.struct.data = original_data
        packet.struct.size = original_size

        return frames
    
    def seek(self, lib.int64_t timestamp, mode = 'backward'):
        """
        Seek to the keyframe at timestamp.
        """
        
        cdef int flags = 0
         
        if mode:
            if mode.lower() == "backward":
                flags = lib.AVSEEK_FLAG_BACKWARD
            elif mode.lower() == "frame":
                flags = lib.AVSEEK_FLAG_FRAME
            elif mode.lower() == "byte":
                flags = lib.AVSEEK_FLAG_BYTE
            elif mode.lower() == 'any':
                flags = lib.AVSEEK_FLAG_ANY
            else:
               raise ValueError("Invalid mode %s" % str(mode))
        
        cdef int result
        with nogil:
            result = lib.av_seek_frame(self._container.ptr, self._stream.index, timestamp, flags)
        err_check(result)
        # flush codec buffers
        cdef lib.AVStream *stream
        for i in xrange(self._container.ptr.nb_streams):
            stream = self._container.ptr.streams[i]
            if stream.codec:
                # don't try and flush unkown codecs
                if not stream.codec.codec_id == lib.AV_CODEC_ID_NONE:
                    lib.avcodec_flush_buffers(stream.codec)
    
    cdef _flush_decoder_frames(self):
        cdef int data_consumed = 0
        cdef list frames = []
        
        cdef Packet packet
        
        cdef Frame frame

        self.packet_pts = lib.AV_NOPTS_VALUE
        while True:
            # Create a new NULL packet for every frame we try to pull out.
            packet = Packet()
            frame = self._decode_one(&packet.struct, &data_consumed)
            if frame:
                if isinstance(frame, Frame):
                    self._setup_frame(frame)
                frames.append(frame)
            else:
                break
            
        return frames
 
    cdef _setup_frame(self, Frame frame):
        #frame.ptr.pts = lib.av_frame_get_best_effort_timestamp(frame.ptr)
        frame.time_base = self._stream.time_base
        frame.index = self._codec_context.frame_number - 1

    cdef _decode_one(self, lib.AVPacket *packet, int *data_consumed):
        raise NotImplementedError('base stream cannot decode packets')

