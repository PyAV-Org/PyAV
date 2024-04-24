import logging
from threading import Lock
from typing import Any, Callable

PANIC: int
FATAL: int
ERROR: int
WARNING: int
INFO: int
VERBOSE: int
DEBUG: int
TRACE: int
CRITICAL: int

def adapt_level(level: int) -> int: ...
def get_level() -> int | None: ...
def set_level(level: int | None) -> None: ...
def restore_default_callback() -> None: ...
def get_skip_repeated() -> bool: ...
def set_skip_repeated(v: bool) -> None: ...
def get_last_error() -> tuple[int, tuple[int, str, str] | None]: ...
def log(level: int, name: str, message: str) -> None: ...

class Capture:
    logs: list[tuple[int, str, str]]

    def __init__(self, local: bool = True) -> None: ...
    def __enter__(self) -> list[tuple[int, str, str]]: ...
    def __exit__(
        self,
        type_: type | None,
        value: Exception | None,
        traceback: Callable[..., Any] | None,
    ) -> None: ...

level_threshold: int
skip_repeated: bool
skip_lock: Lock
last_log: tuple[int, str, str] | None
skip_count: int
last_error: tuple[int, str, str] | None
global_captures: list[list[tuple[int, str, str]]]
thread_captures: dict[int, list[tuple[int, str, str]]]
