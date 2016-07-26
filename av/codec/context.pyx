from libc.stdint cimport uint8_t, int64_t
from libc.string cimport memcpy
from libc.stdlib cimport malloc, realloc, free
from cpython cimport PyWeakref_NewRef

cimport libav as lib

from av.codec.codec cimport Codec, wrap_codec
from av.packet cimport Packet
from av.utils cimport err_check, avdict_to_dict, avrational_to_faction, to_avrational, media_type_to_string

from av.video.codeccontext cimport VideoCodecContext


cdef object _cinit_sentinel = object()


cdef CodecContext wrap_codec_context(lib.AVCodecContext *c_ctx):
    """Build an av.CodecContext for an existing AVCodecContext."""
    
    cdef CodecContext py_ctx

    # TODO: This.
    if c_ctx.codec_type == lib.AVMEDIA_TYPE_VIDEO:
        py_ctx = VideoCodecContext(_cinit_sentinel)
    else:
        py_ctx = CodecContext(_cinit_sentinel)

    py_ctx._init(c_ctx)

    return py_ctx


cdef class CodecContext(object):
    
    @staticmethod
    def create(codec, mode=None):
        cdef Codec cy_codec = codec if isinstance(codec, Codec) else Codec(codec, mode)
        cdef lib.AVCodecContext *c_ctx = lib.avcodec_alloc_context3(cy_codec.ptr)
        return wrap_codec_context(c_ctx)

    def __cinit__(self, sentinel=None, *args, **kwargs):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError('cannot instantiate CodecContext')

    cdef _init(self, lib.AVCodecContext *ptr):
        self.ptr = ptr
        self.codec = wrap_codec(self.ptr.codec)

    @property
    def is_open(self):
        return lib.avcodec_is_open(self.ptr)

    cpdef open(self, bint strict=True):

        if lib.avcodec_is_open(self.ptr):
            if strict:
                raise ValueError('is already open')
            return

        # We might pass partial frames.
        if self.codec.ptr.capabilities & lib.CODEC_CAP_TRUNCATED:
            self.ptr.flags |= lib.CODEC_FLAG_TRUNCATED

        # TODO: Options
        err_check(lib.avcodec_open2(self.ptr, self.codec.ptr, NULL))

    def __dealloc__(self):
        if self.ptr:
            lib.avcodec_close(self.ptr)
        if self.parser:
            lib.av_parser_close(self.parser)
        if self.parse_buffer:
            free(self.parse_buffer)


    def __repr__(self):
        return '<av.%s %s/%s at 0x%x>' % (
            self.__class__.__name__,
            self.type or '<notype>',
            self.name or '<nocodec>',
            id(self),
        )

    property type:
        def __get__(self):
            return self.codec.type
    property name:
        def __get__(self):
            return self.codec.name

    def parse(self, str input_, allow_stream=False):

        if not self.parser:
            self.parser = lib.av_parser_init(self.codec.ptr.id)
        if not self.parser:
            if allow_stream:
                return [Packet(input_)]
            else:
                raise ValueError('no parser for %s' % self.codec.name)

        cdef size_t new_buffer_size
        cdef unsigned char *c_input
        if input_ is not None:

            # Make sure we have enough buffer.
            new_buffer_size = self.parse_buffer_size + len(input_)
            if new_buffer_size > self.parse_buffer_max_size:
                self.parse_buffer = <unsigned char*>realloc(<void*>self.parse_buffer, new_buffer_size)
                self.parse_buffer_max_size = new_buffer_size

            # Copy to the end of the buffer.
            c_input = input_ # for casting
            memcpy(self.parse_buffer + self.parse_buffer_size, c_input, len(input_))
            self.parse_buffer_size = new_buffer_size

        cdef size_t base = 0
        cdef size_t used = 0 # To signal to the while.
        cdef Packet packet = None
        packets = []

        while base < self.parse_buffer_size:
            packet = Packet()
            with nogil:
                used = lib.av_parser_parse2(
                    self.parser,
                    self.ptr,
                    &packet.struct.data, &packet.struct.size,
                    self.parse_buffer + base, self.parse_buffer_size - base,
                    0, 0,
                    self.parse_pos
                )
            err_check(used)

            if packet.struct.size:
                packets.append(packet)
            if used:
                self.parse_pos += used
                base += used

            if not (used or packet.struct.size):
                break

        if base:
            # Shuffle the buffer.
            memcpy(self.parse_buffer, self.parse_buffer + base, base)
            self.parse_buffer_size -= base

        return packets


    cpdef encode(self, Frame frame=None):
        pass

    cpdef decode(self, Packet packet, int count=0):
        """Decode a list of :class:`.Frame` from the given :class:`.Packet`.

        If the packet is None, the buffers will be flushed. This is useful if
        you do not want the library to automatically re-order frames for you
        (if they are encoded with a codec that has B-frames).

        """

        if packet is None:
            raise TypeError('packet must not be None')

        if not self.codec.ptr:
            raise ValueError('cannot decode unknown codec')

        self.open(strict=False)

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
                    pass #self._setup_frame(decoded)
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
    
 
    cdef Frame _decode_one(self, lib.AVPacket *packet, int *data_consumed):
        raise NotImplementedError('base stream cannot decode packets')


