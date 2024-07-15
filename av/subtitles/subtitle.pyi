from typing import Iterator, Literal

class SubtitleSet:
    format: int
    start_display_time: int
    end_display_time: int
    pts: int
    rects: tuple[Subtitle]

    def __len__(self) -> int: ...
    def __iter__(self) -> Iterator[Subtitle]: ...
    def __getitem__(self, i: int) -> Subtitle: ...

class Subtitle: ...

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

class AssSubtitle(Subtitle):
    type: Literal[b"ass", b"text"]
    @property
    def ass(self) -> bytes: ...
    @property
    def dialogue(self) -> bytes: ...
    @property
    def text(self) -> bytes: ...
