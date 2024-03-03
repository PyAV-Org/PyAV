from typing import Any, Iterator, Literal

class SubtitleProxy: ...

class SubtitleSet:
    format: int
    start_display_time: int
    end_display_time: int
    pts: int

    def __len__(self) -> int: ...
    def __iter__(self) -> Iterator[Subtitle]: ...
    def __getitem__(self, i: int) -> Subtitle: ...

class Subtitle:
    type: Literal["none", "bitmap", "text", "ass"]

class BitmapSubtitle(Subtitle):
    type = "bitmap"
    x: int
    y: int
    width: int
    height: int
    nb_colors: Any
    planes: tuple[BitmapSubtitlePlane, ...]

class BitmapSubtitlePlane:
    subtitle: BitmapSubtitle
    index: int
    buffer_size: int

class TextSubtitle(Subtitle):
    type = "text"
    text: str

class AssSubtitle(Subtitle):
    type = "text"
    ass: str
