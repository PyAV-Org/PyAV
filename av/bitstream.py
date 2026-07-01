import cython
import cython.cimports.libav as lib
from cython.cimports.av.codec.codec import Codec
from cython.cimports.av.error import err_check
from cython.cimports.av.packet import Packet
from cython.cimports.av.stream import Stream
from cython.cimports.libc.errno import EAGAIN


@cython.final
@cython.cclass
class BitStreamFilterContext:
    """
    Initializes a bitstream filter: a way to directly modify packet data.

    Wraps :ffmpeg:`AVBSFContext`

    :param in_stream: Defines the input codec for the bitfilter. A :class:`.Stream`
        copies the full input codec parameters, while a :class:`.Codec` or a codec-name
        ``str`` only pins the input codec, which is all a codec-specific filter (such as
        ``h264_mp4toannexb``) needs to initialize.
    :type in_stream: :class:`.Stream`, :class:`.Codec`, str, or None
    :param Stream out_stream: A stream whose codec is overwritten using the output parameters from the bitfilter.
    """

    def __cinit__(
        self,
        filter_description,
        in_stream: Stream | Codec | str | None = None,
        out_stream: Stream | None = None,
    ):
        res: cython.int
        filter_str: cython.p_char = filter_description

        with cython.nogil:
            res = lib.av_bsf_list_parse_str(filter_str, cython.address(self.ptr))
        err_check(res)

        if isinstance(in_stream, Stream):
            with cython.nogil:
                res = lib.avcodec_parameters_copy(
                    self.ptr.par_in, cython.cast(Stream, in_stream).ptr.codecpar
                )
            err_check(res)
        elif in_stream is not None:
            # A Codec or codec name only pins the input codec, which is enough for
            # codec-specific filters (e.g. h264_mp4toannexb) to initialize.
            codec: Codec = (
                in_stream if isinstance(in_stream, Codec) else Codec(in_stream)
            )
            self.ptr.par_in.codec_id = codec.ptr.id
            self.ptr.par_in.codec_type = codec.ptr.type

        with cython.nogil:
            res = lib.av_bsf_init(self.ptr)
        err_check(res)

        if out_stream is not None:
            with cython.nogil:
                res = lib.avcodec_parameters_copy(
                    out_stream.ptr.codecpar, self.ptr.par_out
                )
            err_check(res)
            lib.avcodec_parameters_to_context(
                out_stream.codec_context.ptr, out_stream.ptr.codecpar
            )

    def __dealloc__(self):
        if self.ptr:
            lib.av_bsf_free(cython.address(self.ptr))

    @cython.ccall
    def filter(self, packet: Packet | None = None):
        """
        Processes a packet based on the filter_description set during initialization.
        Multiple packets may be created.

        :type: list[Packet]
        """
        res: cython.int
        new_packet: Packet

        with cython.nogil:
            res = lib.av_bsf_send_packet(
                self.ptr, packet.ptr if packet is not None else cython.NULL
            )
        err_check(res)

        output: list = []
        while True:
            new_packet = Packet()
            with cython.nogil:
                res = lib.av_bsf_receive_packet(self.ptr, new_packet.ptr)

            if res == -EAGAIN or res == lib.AVERROR_EOF:
                return output

            err_check(res)
            if res:
                return output

            output.append(new_packet)

    @cython.ccall
    def flush(self):
        """
        Reset the internal state of the filter.
        Should be called e.g. when seeking.
        Can be used to make the filter usable again after draining it with EOF marker packet.
        """
        lib.av_bsf_flush(self.ptr)


@cython.cfunc
def get_filter_names() -> set:
    names: set = set()
    ptr: cython.pointer[cython.const[lib.AVBitStreamFilter]]
    opaque: cython.p_void = cython.NULL
    while True:
        ptr = lib.av_bsf_iterate(cython.address(opaque))
        if ptr:
            names.add(ptr.name)
        else:
            break

    return names


bitstream_filters_available = get_filter_names()
