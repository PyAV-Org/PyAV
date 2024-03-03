from .enum import EnumItem

classes: dict[int, Exception]

def code_to_tag(code: int) -> bytes: ...
def tag_to_code(tag: bytes) -> int: ...
def make_error(
    res: int,
    filename: str | None = None,
    log: tuple[int, tuple[int, str, str] | None] | None = None,
) -> None: ...

class ErrorType(EnumItem):
    BSF_NOT_FOUND: int
    BUG: int
    BUFFER_TOO_SMALL: int
    DECODER_NOT_FOUND: int
    DEMUXER_NOT_FOUND: int
    ENCODER_NOT_FOUND: int
    EOF: int
    EXIT: int
    EXTERNAL: int
    FILTER_NOT_FOUND: int
    INVALIDDATA: int
    MUXER_NOT_FOUND: int
    OPTION_NOT_FOUND: int
    PATCHWELCOME: int
    PROTOCOL_NOT_FOUND: int
    UNKNOWN: int
    EXPERIMENTAL: int
    INPUT_CHANGED: int
    OUTPUT_CHANGED: int
    HTTP_BAD_REQUEST: int
    HTTP_UNAUTHORIZED: int
    HTTP_FORBIDDEN: int
    HTTP_NOT_FOUND: int
    HTTP_OTHER_4XX: int
    HTTP_SERVER_ERROR: int
    PYAV_CALLBACK: int

    tag: bytes

class FFmpegError(Exception):
    errno: int
    strerror: str
    filename: str
    log: tuple[int, tuple[int, str, str] | None]

    def __init__(
        self,
        code: int,
        message: str,
        filename: str | None = None,
        log: tuple[int, tuple[int, str, str] | None] | None = None,
    ) -> None: ...

class LookupError(FFmpegError): ...
class HTTPError(FFmpegError): ...
class HTTPClientError(FFmpegError): ...
class UndefinedError(FFmpegError): ...
class InvalidDataError(ValueError): ...
