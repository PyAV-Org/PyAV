import errno
from traceback import format_exception_only

import av

from .common import is_windows


def test_stringify() -> None:
    for cls in (av.ValueError, av.FileNotFoundError, av.DecoderNotFoundError):
        e = cls(1, "foo")
        assert f"{e}" == "[Errno 1] foo"
        assert f"{e!r}" == f"{cls.__name__}(1, 'foo')"
        assert (
            format_exception_only(cls, e)[-1]
            == f"av.error.{cls.__name__}: [Errno 1] foo\n"
        )

    for cls in (av.ValueError, av.FileNotFoundError, av.DecoderNotFoundError):
        e = cls(1, "foo", "bar.txt")
        assert f"{e}" == "[Errno 1] foo: 'bar.txt'"
        assert f"{e!r}" == f"{cls.__name__}(1, 'foo', 'bar.txt')"
        assert (
            format_exception_only(cls, e)[-1]
            == f"av.error.{cls.__name__}: [Errno 1] foo: 'bar.txt'\n"
        )


def test_bases() -> None:
    assert issubclass(av.ValueError, ValueError)
    assert issubclass(av.ValueError, av.FFmpegError)

    assert issubclass(av.FileNotFoundError, FileNotFoundError)
    assert issubclass(av.FileNotFoundError, OSError)
    assert issubclass(av.FileNotFoundError, av.FFmpegError)


def test_filenotfound():
    """Catch using builtin class on Python 3.3"""
    try:
        av.open("does not exist")
    except FileNotFoundError as e:
        assert e.errno == errno.ENOENT
        if is_windows:
            assert e.strerror in (
                "Error number -2 occurred",
                "No such file or directory",
            )
        else:
            assert e.strerror == "No such file or directory"
        assert e.filename == "does not exist"
    else:
        assert False, "No exception raised!"


def test_buffertoosmall() -> None:
    """Throw an exception from an enum."""
    try:
        av.error.err_check(-av.error.BUFFER_TOO_SMALL.value)
    except av.error.BufferTooSmallError as e:
        assert e.errno == av.error.BUFFER_TOO_SMALL.value
    else:
        assert False, "No exception raised!"
