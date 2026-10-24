from collections.abc import Iterator
from typing import Literal, final

from typing_extensions import disjoint_base

@final
class SubtitleProxy: ...

@final
class SubtitleSet:
    format: int
    start_display_time: int
    end_display_time: int
    pts: int
    rects: tuple[AssSubtitle | BitmapSubtitle, ...]

    @staticmethod
    def create(
        text: bytes,
        start: int,
        end: int,
        pts: int = 0,
        subtitle_format: int = 1,
    ) -> SubtitleSet: ...
    def __len__(self) -> int: ...
    def __iter__(self) -> Iterator[AssSubtitle | BitmapSubtitle]: ...
    def __getitem__(self, i: int, /) -> AssSubtitle | BitmapSubtitle: ...

@disjoint_base
class Subtitle:
    type: bytes

@final
class BitmapSubtitle(Subtitle):
    type: Literal[b"bitmap"]
    x: int
    y: int
    width: int
    height: int
    nb_colors: int
    planes: tuple[BitmapSubtitlePlane, ...]
    def __len__(self) -> int: ...
    def __iter__(self) -> Iterator[BitmapSubtitlePlane]: ...
    def __getitem__(self, i: int, /) -> BitmapSubtitlePlane: ...

@final
class BitmapSubtitlePlane:
    subtitle: BitmapSubtitle
    index: int
    buffer_size: int
    def __buffer__(self, flags: int, /) -> memoryview: ...

@final
class AssSubtitle(Subtitle):
    type: Literal[b"ass", b"text"]
    @property
    def ass(self) -> bytes: ...
    @property
    def dialogue(self) -> bytes: ...
    @property
    def text(self) -> bytes: ...
