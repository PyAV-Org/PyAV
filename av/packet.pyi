from fractions import Fraction
from typing import Generic, Iterator, Literal, TypeVar, overload

from av.audio.frame import AudioFrame
from av.audio.stream import AudioStream
from av.subtitles.stream import SubtitleStream
from av.subtitles.subtitle import AssSubtitle, BitmapSubtitle, SubtitleSet
from av.video.frame import VideoFrame
from av.video.stream import VideoStream
from av.stream import Stream, DataStream, AttachmentStream

from .buffer import Buffer
from .stream import Stream

# Sync with definition in 'packet.py'
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

class PacketSideData(Buffer):
    @staticmethod
    def from_packet(packet: Packet[Stream], dtype: PktSideDataT) -> PacketSideData: ...
    def to_packet(self, packet: Packet[Stream], move: bool = False): ...
    @property
    def data_type(self) -> str: ...
    @property
    def data_desc(self) -> str: ...
    @property
    def data_size(self) -> int: ...
    def __bool__(self) -> bool: ...

def packet_sidedata_type_to_literal(dtype: int) -> PktSideDataT: ...
def packet_sidedata_type_from_literal(dtype: PktSideDataT) -> int: ...

# TypeVar for stream types - bound to Stream so it can be any stream type
StreamT = TypeVar('StreamT', bound=Stream)

class Packet(Buffer, Generic[StreamT]):
    stream: StreamT
    stream_index: int
    time_base: Fraction
    pts: int | None
    dts: int | None
    pos: int | None
    size: int
    duration: int | None
    opaque: object
    is_keyframe: bool
    is_corrupt: bool
    is_discard: bool
    is_trusted: bool
    is_disposable: bool

    def __init__(self: Packet[Stream], input: int | bytes | None = None) -> None: ...
    
    # Overloads that return the same type as the stream's decode method
    @overload
    def decode(self: Packet[VideoStream]) -> list[VideoFrame]: ...
    @overload  
    def decode(self: Packet[AudioStream]) -> list[AudioFrame]: ...
    @overload
    def decode(self: Packet[SubtitleStream]) -> list[AssSubtitle] | list[BitmapSubtitle]: ...
    @overload
    def decode(self) -> list[VideoFrame | AudioFrame | AssSubtitle | BitmapSubtitle]: ...

    def has_sidedata(self, dtype: PktSideDataT) -> bool: ...
    def get_sidedata(self, dtype: PktSideDataT) -> PacketSideData: ...
    def set_sidedata(self, sidedata: PacketSideData, move: bool = False) -> None: ...
    def iter_sidedata(self) -> Iterator[PacketSideData]: ...
