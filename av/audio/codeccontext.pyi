from collections.abc import Iterator
from typing import Any, Literal, final, override

from av.codec.context import CodecContext
from av.packet import Packet
from av.stream import Stream

from .format import AudioFormat
from .frame import AudioFrame
from .layout import AudioLayout

@final
class AudioCodecContext(CodecContext):
    frame_size: int
    sample_rate: int
    rate: int
    type: Literal["audio"]
    @property
    def format(self) -> AudioFormat | None: ...
    @format.setter
    def format(self, value: AudioFormat | str) -> None: ...
    @property
    def layout(self) -> AudioLayout: ...
    @layout.setter
    def layout(self, value: AudioLayout | str) -> None: ...
    @property
    def channels(self) -> int: ...
    @property
    def block_align(self) -> int: ...
    @override
    def encode(self, frame: AudioFrame | None = None) -> list[Packet[Stream]]: ...  # type: ignore[override]
    @override
    def encode_lazy(  # type: ignore[override]
        self, frame: AudioFrame | None = None
    ) -> Iterator[Packet[Stream]]: ...
    @override
    def decode(self, packet: Packet[Any] | None = None) -> list[AudioFrame]: ...
