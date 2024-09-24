import errno
import traceback

import av

from .common import TestCase, is_windows


class TestErrorBasics(TestCase):
    def test_stringify(self) -> None:
        for cls in (av.ValueError, av.FileNotFoundError, av.DecoderNotFoundError):
            e = cls(1, "foo")
            assert f"{e}" == "[Errno 1] foo"
            assert f"{e!r}" == f"{cls.__name__}(1, 'foo')"
            assert (
                traceback.format_exception_only(cls, e)[-1]
                == f"av.error.{cls.__name__}: [Errno 1] foo\n"
            )

        for cls in (av.ValueError, av.FileNotFoundError, av.DecoderNotFoundError):
            e = cls(1, "foo", "bar.txt")
            assert f"{e}" == "[Errno 1] foo: 'bar.txt'"
            assert f"{e!r}" == f"{cls.__name__}(1, 'foo', 'bar.txt')"
            assert (
                traceback.format_exception_only(cls, e)[-1]
                == f"av.error.{cls.__name__}: [Errno 1] foo: 'bar.txt'\n"
            )

    def test_bases(self) -> None:
        assert issubclass(av.ValueError, ValueError)
        assert issubclass(av.ValueError, av.FFmpegError)

        assert issubclass(av.FileNotFoundError, FileNotFoundError)
        assert issubclass(av.FileNotFoundError, OSError)
        assert issubclass(av.FileNotFoundError, av.FFmpegError)

    def test_filenotfound(self):
        """Catch using builtin class on Python 3.3"""
        try:
            av.open("does not exist")
        except FileNotFoundError as e:
            assert e.errno == errno.ENOENT
            if is_windows:
                self.assertTrue(
                    e.strerror
                    in ["Error number -2 occurred", "No such file or directory"]
                )
            else:
                assert e.strerror == "No such file or directory"
            assert e.filename == "does not exist"
        else:
            self.fail("no exception raised")

    def test_buffertoosmall(self):
        """Throw an exception from an enum."""
        try:
            av.error.err_check(-av.error.BUFFER_TOO_SMALL.value)
        except av.BufferTooSmallError as e:
            assert e.errno == av.error.BUFFER_TOO_SMALL.value
        else:
            self.fail("no exception raised")
