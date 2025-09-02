from typing import Iterator, Literal, get_args

import cython
from cython.cimports import libav as lib
from cython.cimports.av.bytesource import bytesource
from cython.cimports.av.error import err_check
from cython.cimports.av.opaque import opaque_container
from cython.cimports.av.utils import avrational_to_fraction, to_avrational
from cython.cimports.libc.string import memcpy

# Check https://github.com/FFmpeg/FFmpeg/blob/master/libavcodec/packet.h#L41
# for new additions in the future ffmpeg releases
# Note: the order must follow that of the AVPacketSideDataType enum def
PktSideDataT = Literal[
    "palette",
    "new_extradata",
    "param_change",
    "h263_mb_info",
    "replay_gain",
    "display_matrix",
    "stereo_3d",
    "audio_service_type",
    "quality_stats",
    "fallback_track",
    "cpb_properties",
    "skip_samples",
    "jp_dual_mono",
    "strings_metadata",
    "subtitle_position",
    "matroska_block_additional",
    "webvtt_identifier",
    "webvtt_settings",
    "metadata_update",
    "mpegts_stream_id",
    "mastering_display_metadata",
    "spherical",
    "content_light_level",
    "a53_cc",
    "encryption_init_info",
    "encryption_info",
    "afd",
    "prft",
    "icc_profile",
    "dovi_conf",
    "s12m_timecode",
    "dynamic_hdr10_plus",
    "iamf_mix_gain_param",
    "iamf_info_param",
    "iamf_recon_gain_info_param",
    "ambient_viewing_environment",
    "frame_cropping",
    "lcevc",
    "3d_reference_displays",
    "rtcp_sr",
]


def packet_sidedata_type_to_literal(dtype: lib.AVPacketSideDataType) -> PktSideDataT:
    return get_args(PktSideDataT)[cython.cast(int, dtype)]


def packet_sidedata_type_from_literal(dtype: PktSideDataT) -> lib.AVPacketSideDataType:
    return get_args(PktSideDataT).index(dtype)


@cython.cclass
class PacketSideData:
    @staticmethod
    def from_packet(packet: Packet, data_type: PktSideDataT) -> PacketSideData:
        """create new PacketSideData by copying an existing packet's side data

        :param packet: Source packet
        :type packet: :class:`~av.packet.Packet`
        :param data_type: side data type
        :return: newly created copy of the side data if the side data of the
                 requested type is found in the packet, else an empty object
        :rtype: :class:`~av.packet.PacketSideData`
        """

        dtype = packet_sidedata_type_from_literal(data_type)
        return _packet_sidedata_from_packet(packet.ptr, dtype)

    def __cinit__(self, dtype: lib.AVPacketSideDataType, size: cython.size_t):
        self.dtype = dtype
        with cython.nogil:
            if size:
                self.data = cython.cast(cython.p_uchar, lib.av_malloc(size))
                if self.data == cython.NULL:
                    raise MemoryError("Failed to allocate memory")
            else:
                self.data = cython.NULL
        self.size = size

    def __dealloc__(self):
        with cython.nogil:
            lib.av_freep(cython.address(self.data))

    def to_packet(self, packet: Packet, move: cython.bint = False):
        """copy or move side data to the specified packet

        :param packet: Target packet
        :type packet: :class:`~av.packet.Packet`
        :param move: True to move the data from this object to the packet,
                     defaults to False.
        :type move: bool
        """
        if self.size == 0:
            # nothing to add, should clear existing side_data in packet?
            return

        data = self.data

        with cython.nogil:
            if not move:
                data = cython.cast(cython.p_uchar, lib.av_malloc(self.size))
                if data == cython.NULL:
                    raise MemoryError("Failed to allocate memory")
                memcpy(data, self.data, self.size)

            res = lib.av_packet_add_side_data(packet.ptr, self.dtype, data, self.size)
        err_check(res)

        if move:
            self.data = cython.NULL
            self.size = 0

    @property
    def data_type(self) -> str:
        """
        The type of this packet side data.

        :type: str
        """
        return packet_sidedata_type_to_literal(self.dtype)

    @property
    def data_desc(self) -> str:
        """
        The description of this packet side data type.

        :type: str
        """

        return lib.av_packet_side_data_name(self.dtype)

    @property
    def data_size(self) -> int:
        """
        The size in bytes of this packet side data.

        :type: int
        """
        return self.size

    def __bool__(self) -> bool:
        """
        True if this object holds side data.

        :type: bool
        """
        return self.data != cython.NULL


@cython.cfunc
def _packet_sidedata_from_packet(
    packet: cython.pointer[lib.AVPacket], dtype: lib.AVPacketSideDataType
) -> PacketSideData:
    with cython.nogil:
        c_ptr = lib.av_packet_side_data_get(
            packet.side_data, packet.side_data_elems, dtype
        )
        found: cython.bint = c_ptr != cython.NULL

    sdata = PacketSideData(dtype, c_ptr.size if found else 0)

    with cython.nogil:
        if found:
            memcpy(sdata.data, c_ptr.data, c_ptr.size)

    return sdata


@cython.cclass
class Packet(Buffer):
    """A packet of encoded data within a :class:`~av.format.Stream`.

    This may, or may not include a complete object within a stream.
    :meth:`decode` must be called to extract encoded data.
    """

    def __cinit__(self, input=None):
        with cython.nogil:
            self.ptr = lib.av_packet_alloc()

    def __dealloc__(self):
        with cython.nogil:
            lib.av_packet_free(cython.address(self.ptr))

    def __init__(self, input=None):
        size: cython.size_t = 0
        source: ByteSource = None

        if input is None:
            return

        if isinstance(input, int):
            size = input
        else:
            source = bytesource(input)
            size = source.length

        if size:
            err_check(lib.av_new_packet(self.ptr, size))

        if source is not None:
            self.update(source)
            # TODO: Hold onto the source, and copy its pointer
            # instead of its data.
            # self.source = source

    def __repr__(self):
        stream = self._stream.index if self._stream else 0
        return (
            f"av.{self.__class__.__name__} of #{stream}, dts={self.dts},"
            f" pts={self.pts}; {self.ptr.size} bytes at 0x{id(self):x}>"
        )

    # Buffer protocol.
    @cython.cfunc
    def _buffer_size(self) -> cython.size_t:
        return self.ptr.size

    @cython.cfunc
    def _buffer_ptr(self) -> cython.p_void:
        return self.ptr.data

    @cython.cfunc
    def _rebase_time(self, dst: lib.AVRational):
        if not dst.num:
            raise ValueError("Cannot rebase to zero time.")

        if not self.ptr.time_base.num:
            self.ptr.time_base = dst
            return

        if self.ptr.time_base.num == dst.num and self.ptr.time_base.den == dst.den:
            return

        lib.av_packet_rescale_ts(self.ptr, self.ptr.time_base, dst)
        self.ptr.time_base = dst

    def decode(self):
        """
        Send the packet's data to the decoder and return a list of
        :class:`.AudioFrame`, :class:`.VideoFrame` or :class:`.SubtitleSet`.
        """
        return self._stream.decode(self)

    @property
    def stream_index(self):
        return self.ptr.stream_index

    @property
    def stream(self):
        """
        The :class:`Stream` this packet was demuxed from.
        """
        return self._stream

    @stream.setter
    def stream(self, stream: Stream):
        self._stream = stream
        self.ptr.stream_index = stream.ptr.index

    @property
    def time_base(self):
        """
        The unit of time (in fractional seconds) in which timestamps are expressed.

        :type: fractions.Fraction
        """
        return avrational_to_fraction(cython.address(self.ptr.time_base))

    @time_base.setter
    def time_base(self, value):
        to_avrational(value, cython.address(self.ptr.time_base))

    @property
    def pts(self):
        """
        The presentation timestamp in :attr:`time_base` units for this packet.

        This is the time at which the packet should be shown to the user.

        :type: int | None
        """
        if self.ptr.pts != lib.AV_NOPTS_VALUE:
            return self.ptr.pts

    @pts.setter
    def pts(self, v):
        if v is None:
            self.ptr.pts = lib.AV_NOPTS_VALUE
        else:
            self.ptr.pts = v

    @property
    def dts(self):
        """
        The decoding timestamp in :attr:`time_base` units for this packet.

        :type: int | None
        """
        if self.ptr.dts != lib.AV_NOPTS_VALUE:
            return self.ptr.dts

    @dts.setter
    def dts(self, v):
        if v is None:
            self.ptr.dts = lib.AV_NOPTS_VALUE
        else:
            self.ptr.dts = v

    @property
    def pos(self):
        """
        The byte position of this packet within the :class:`.Stream`.

        Returns `None` if it is not known.

        :type: int | None
        """
        if self.ptr.pos != -1:
            return self.ptr.pos

    @property
    def size(self):
        """
        The size in bytes of this packet's data.

        :type: int
        """
        return self.ptr.size

    @property
    def duration(self):
        """
        The duration in :attr:`time_base` units for this packet.

        Returns `None` if it is not known.

        :type: int
        """
        if self.ptr.duration != lib.AV_NOPTS_VALUE:
            return self.ptr.duration

    @duration.setter
    def duration(self, v):
        if v is None:
            self.ptr.duration = lib.AV_NOPTS_VALUE
        else:
            self.ptr.duration = v

    @property
    def is_keyframe(self):
        return bool(self.ptr.flags & lib.AV_PKT_FLAG_KEY)

    @is_keyframe.setter
    def is_keyframe(self, v):
        if v:
            self.ptr.flags |= lib.AV_PKT_FLAG_KEY
        else:
            self.ptr.flags &= ~(lib.AV_PKT_FLAG_KEY)

    @property
    def is_corrupt(self):
        return bool(self.ptr.flags & lib.AV_PKT_FLAG_CORRUPT)

    @is_corrupt.setter
    def is_corrupt(self, v):
        if v:
            self.ptr.flags |= lib.AV_PKT_FLAG_CORRUPT
        else:
            self.ptr.flags &= ~(lib.AV_PKT_FLAG_CORRUPT)

    @property
    def is_discard(self):
        return bool(self.ptr.flags & lib.AV_PKT_FLAG_DISCARD)

    @property
    def is_trusted(self):
        return bool(self.ptr.flags & lib.AV_PKT_FLAG_TRUSTED)

    @property
    def is_disposable(self):
        return bool(self.ptr.flags & lib.AV_PKT_FLAG_DISPOSABLE)

    @property
    def opaque(self):
        if self.ptr.opaque_ref is not cython.NULL:
            return opaque_container.get(
                cython.cast(cython.p_char, self.ptr.opaque_ref.data)
            )

    @opaque.setter
    def opaque(self, v):
        lib.av_buffer_unref(cython.address(self.ptr.opaque_ref))

        if v is None:
            return
        self.ptr.opaque_ref = opaque_container.add(v)

    def has_sidedata(self, dtype: str) -> bool:
        """True if this packet has the specified side data

        :param dtype: side data type
        :type dtype: str
        """

        dtype2 = packet_sidedata_type_from_literal(dtype)
        return (
            lib.av_packet_side_data_get(
                self.ptr.side_data, self.ptr.side_data_elems, dtype2
            )
            != cython.NULL
        )

    def get_sidedata(self, dtype: str) -> PacketSideData:
        """get a copy of the side data

        :param dtype: side data type (:method:`~av.packet.PacketSideData.sidedata_types` for the full list of options)
        :type dtype: str
        :return: newly created copy of the side data if the side data of the
                 requested type is found in the packet, else an empty object
        :rtype: :class:`~av.packet.PacketSideData`
        """
        return PacketSideData.from_packet(self, dtype)

    def set_sidedata(self, sidedata: PacketSideData, move: cython.bint = False):
        """copy or move side data to this packet

        :param sidedata: Source packet side data
        :type sidedata: :class:`~av.packet.PacketSideData`
        :param move: If True, move the data from `sidedata` object, defaults to False
        :type move: bool
        """
        sidedata.to_packet(self, move)

    def iter_sidedata(self) -> Iterator[PacketSideData]:
        """iterate over side data of this packet.

        :yield: :class:`~av.packet.PacketSideData` object
        """

        for i in range(self.ptr.side_data_elems):
            yield _packet_sidedata_from_packet(self.ptr, self.ptr.side_data[i].type)
