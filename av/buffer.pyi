from collections.abc import Buffer as _Buffer
from typing import final

from typing_extensions import disjoint_base

@final
class ByteSource: ...

@disjoint_base
class Buffer(_Buffer):
    buffer_size: int
    buffer_ptr: int
    def update(self, input: bytes) -> None: ...
    def __buffer__(self, flags: int, /) -> memoryview: ...
