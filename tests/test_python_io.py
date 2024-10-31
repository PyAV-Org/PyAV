from __future__ import annotations

import functools
import io
import types
from io import BytesIO
from re import escape
from typing import TYPE_CHECKING

import pytest

import av

from .common import TestCase, fate_png, fate_suite, has_pillow, run_in_sandbox
from .test_encode import assert_rgb_rotate, write_rgb_rotate

if TYPE_CHECKING:
    from collections.abc import Callable


class MethodLogger:
    def __init__(self, obj: object) -> None:
        self._obj = obj
        self._log: list[tuple[str, object]] = []

    def __getattr__(self, name: str) -> object:
        def _method(name: str, meth: Callable, *args, **kwargs) -> object:
            self._log.append((name, args))
            return meth(*args, **kwargs)

        value = getattr(self._obj, name)
        if isinstance(
            value,
            (
                types.MethodType,
                types.FunctionType,
                types.BuiltinFunctionType,
                types.BuiltinMethodType,
            ),
        ):
            return functools.partial(_method, name, value)
        else:
            self._log.append(("__getattr__", (name,)))
            return value

    def _filter(self, type_: str) -> list[tuple[str, object]]:
        return [log for log in self._log if log[0] == type_]


class BrokenBuffer(BytesIO):
    """
    Buffer which can be "broken" to simulate an I/O error.
    """

    broken = False

    def write(self, data):
        if self.broken:
            raise OSError("It's broken")
        else:
            return super().write(data)


class ReadOnlyBuffer:
    """
    Minimal buffer which *only* implements the read() method.
    """

    def __init__(self, data) -> None:
        self.data = data

    def read(self, n):
        data = self.data[0:n]
        self.data = self.data[n:]
        return data


class ReadOnlyPipe(BytesIO):
    """
    Buffer which behaves like a readable pipe.
    """

    @property
    def name(self) -> int:
        return 123

    def seekable(self) -> bool:
        return False

    def writable(self) -> bool:
        return False


class WriteOnlyPipe(BytesIO):
    """
    Buffer which behaves like a writable pipe.
    """

    @property
    def name(self) -> int:
        return 123

    def readable(self) -> bool:
        return False

    def seekable(self) -> bool:
        return False


def read(
    fh: io.BufferedReader | BytesIO | ReadOnlyBuffer, seekable: bool = True
) -> None:
    wrapped = MethodLogger(fh)

    with av.open(wrapped, "r") as container:
        assert container.format.name == "mpegts"
        assert container.format.long_name == "MPEG-TS (MPEG-2 Transport Stream)"
        assert len(container.streams) == 1
        if seekable:
            assert container.size == 800000
        assert container.metadata == {}

    # Check method calls.
    assert wrapped._filter("read")
    if seekable:
        assert wrapped._filter("seek")


def write(fh: io.BufferedWriter | BytesIO) -> None:
    wrapped = MethodLogger(fh)

    with av.open(wrapped, "w", "mp4") as container:
        write_rgb_rotate(container)

    # Check method calls.
    assert wrapped._filter("write")
    assert wrapped._filter("seek")


# Using a custom protocol will avoid the DASH muxer detecting or defaulting to a
# file: protocol and enabling the use of temporary files and renaming.
CUSTOM_IO_PROTOCOL = "pyavtest://"


class CustomIOLogger:
    """Log calls to open a file as well as method calls on the files"""

    def __init__(self) -> None:
        self._log: list[tuple[object, dict]] = []
        self._method_log: list[MethodLogger] = []

    def __call__(self, *args, **kwargs) -> MethodLogger:
        self._log.append((args, kwargs))
        self._method_log.append(self.io_open(*args, **kwargs))
        return self._method_log[-1]

    def io_open(self, url: str, flags, options: object) -> MethodLogger:
        # Remove the protocol prefix to reveal the local filename
        if CUSTOM_IO_PROTOCOL in url:
            url = url.split(CUSTOM_IO_PROTOCOL, 1)[1]

        if (flags & 3) == 3:
            mode = "r+b"
        elif (flags & 1) == 1:
            mode = "rb"
        elif (flags & 2) == 2:
            mode = "wb"
        else:
            raise RuntimeError(f"Unsupported io open mode {flags}")

        return MethodLogger(open(url, mode))


class TestPythonIO(TestCase):
    def test_basic_errors(self) -> None:
        self.assertRaises(Exception, av.open, None)
        self.assertRaises(Exception, av.open, None, "w")

    def test_reading_from_buffer(self) -> None:
        with open(fate_suite("mpeg2/mpeg2_field_encoding.ts"), "rb") as fh:
            buf = BytesIO(fh.read())
        read(buf, seekable=True)

    def test_reading_from_buffer_no_seek(self) -> None:
        with open(fate_suite("mpeg2/mpeg2_field_encoding.ts"), "rb") as fh:
            buf = ReadOnlyBuffer(fh.read())
        read(buf, seekable=False)

    def test_reading_from_file(self) -> None:
        with open(fate_suite("mpeg2/mpeg2_field_encoding.ts"), "rb") as fh:
            read(fh, seekable=True)

    def test_reading_from_pipe_readonly(self) -> None:
        with open(fate_suite("mpeg2/mpeg2_field_encoding.ts"), "rb") as fh:
            buf = ReadOnlyPipe(fh.read())
        read(buf, seekable=False)

    def test_reading_from_write_readonly(self) -> None:
        with open(fate_suite("mpeg2/mpeg2_field_encoding.ts"), "rb") as fh:
            buf = WriteOnlyPipe(fh.read())

        msg = escape("File object has no read() method, or readable() returned False.")
        with pytest.raises(ValueError, match=msg):
            read(buf, seekable=False)

    def test_writing_to_buffer(self) -> None:
        buf = BytesIO()

        write(buf)

        # Check contents.
        assert buf.tell()
        buf.seek(0)
        with av.open(buf, "r") as container:
            assert_rgb_rotate(self, container)

    def test_writing_to_buffer_broken(self) -> None:
        buf = BrokenBuffer()

        with pytest.raises(OSError):
            with av.open(buf, "w", "mp4") as container:
                write_rgb_rotate(container)

                # break I/O
                buf.broken = True

    def test_writing_to_buffer_broken_with_close(self) -> None:
        buf = BrokenBuffer()

        with av.open(buf, "w", "mp4") as container:
            write_rgb_rotate(container)

            # break I/O
            buf.broken = True

            # try to close file
            with pytest.raises(OSError):
                container.close()

    @run_in_sandbox
    def test_writing_to_custom_io_dash(self) -> None:
        # Custom I/O that opens file and logs calls
        wrapped_custom_io = CustomIOLogger()

        output_filename = "custom_io_output.mpd"

        # Write a DASH package using the custom IO. Prefix the name with CUSTOM_IO_PROTOCOL to
        # avoid temporary file and renaming.
        with av.open(
            CUSTOM_IO_PROTOCOL + output_filename, "w", io_open=wrapped_custom_io
        ) as container:
            write_rgb_rotate(container)

        # Check that at least 3 files were opened using the custom IO:
        #   "output_filename", init-stream0.m4s and chunk-stream-0x.m4s
        assert len(wrapped_custom_io._log) >= 3
        assert len(wrapped_custom_io._method_log) >= 3

        # Check that all files were written to
        all_write = all(
            method_log._filter("write") for method_log in wrapped_custom_io._method_log
        )
        assert all_write

        # Check that all files were closed
        all_closed = all(
            method_log._filter("close") for method_log in wrapped_custom_io._method_log
        )
        assert all_closed

        # Check contents.
        # Note that the dash demuxer doesn't support custom I/O.
        with av.open(output_filename, "r") as container:
            assert_rgb_rotate(self, container, is_dash=True)

    def test_writing_to_custom_io_image2(self) -> None:
        if not has_pillow:
            pytest.skip()

        import PIL.Image as Image

        # Custom I/O that opens file and logs calls
        wrapped_custom_io = CustomIOLogger()

        image = Image.open(fate_png())
        input_frame = av.VideoFrame.from_image(image)

        frame_count = 10
        sequence_filename = self.sandboxed("test%d.png")
        width = 160
        height = 90

        # Write a PNG image sequence using the custom IO
        with av.open(
            sequence_filename, "w", "image2", io_open=wrapped_custom_io
        ) as output:
            stream = output.add_stream("png")
            stream.width = width
            stream.height = height
            stream.pix_fmt = "rgb24"

            for _ in range(frame_count):
                for packet in stream.encode(input_frame):
                    output.mux(packet)

        # Check that "frame_count" files were opened using the custom IO
        assert len(wrapped_custom_io._log) == frame_count
        assert len(wrapped_custom_io._method_log) == frame_count

        # Check that all files were written to
        all_write = all(
            method_log._filter("write") for method_log in wrapped_custom_io._method_log
        )
        assert all_write

        # Check that all files were closed
        all_closed = all(
            method_log._filter("close") for method_log in wrapped_custom_io._method_log
        )
        assert all_closed

        # Check contents.
        with av.open(sequence_filename, "r", "image2") as container:
            assert len(container.streams) == 1
            assert isinstance(container.streams[0], av.video.stream.VideoStream)

            stream = container.streams[0]
            assert stream.duration == frame_count
            assert stream.type == "video"

            # codec context properties
            assert stream.codec.name == "png"
            assert stream.format.name == "rgb24"
            assert stream.format.width == width
            assert stream.format.height == height

    def test_writing_to_file(self) -> None:
        path = self.sandboxed("writing.mp4")

        with open(path, "wb") as fh:
            write(fh)

        # Check contents.
        with av.open(path) as container:
            assert_rgb_rotate(self, container)

    def test_writing_to_pipe_readonly(self) -> None:
        buf = ReadOnlyPipe()
        with pytest.raises(
            ValueError,
            match=escape(
                "File object has no write() method, or writable() returned False."
            ),
        ) as cm:
            write(buf)

    def test_writing_to_pipe_writeonly(self) -> None:
        av.logging.set_level(av.logging.VERBOSE)

        buf = WriteOnlyPipe()
        with pytest.raises(
            ValueError, match=escape("[mp4] muxer does not support non seekable output")
        ):
            write(buf)

        av.logging.set_level(None)
