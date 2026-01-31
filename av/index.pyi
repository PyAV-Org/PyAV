from typing import Iterator, overload

class IndexEntry:
    pos: int
    timestamp: int
    flags: int
    is_keyframe: bool
    is_discard: bool
    size: int
    min_distance: int

class IndexEntries:
    def __len__(self) -> int: ...
    def __iter__(self) -> Iterator[IndexEntry]: ...
    @overload
    def __getitem__(self, index: int) -> IndexEntry: ...
    @overload
    def __getitem__(self, index: slice) -> list[IndexEntry]: ...
    def search_timestamp(
        self, timestamp, *, backward: bool = True, any_frame: bool = False
    ) -> int: ...
