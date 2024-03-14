from typing import Iterator, Literal

class SubtitleSet:
    format: int
    start_display_time: int
    end_display_time: int
    pts: int

    def __len__(self) -> int: ...
    def __iter__(self) -> Iterator[Subtitle]: ...
    def __getitem__(self, i: int) -> Subtitle: ...

class Subtitle:
    type: Literal[b"none", b"bitmap", b"text", b"ass"]

class BitmapSubtitle(Subtitle):
    type: Literal[b"bitmap"]
    x: int
    y: int
    width: int
    height: int
    nb_colors: int
    planes: tuple[BitmapSubtitlePlane, ...]

class BitmapSubtitlePlane:
    subtitle: BitmapSubtitle
    index: int
    buffer_size: int

class TextSubtitle(Subtitle):
    type: Literal[b"text"]
    text: str

class AssSubtitle(Subtitle):
    type: Literal[b"ass"]
    ass: bytes
