class Buffer:
    buffer_size: int
    buffer_ptr: int
    def update(self, input: bytes) -> None: ...
