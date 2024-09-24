import functools
import types
from io import BytesIO
from unittest import SkipTest

import av

from .common import TestCase, fate_png, fate_suite, has_pillow, run_in_sandbox
from .test_encode import assert_rgb_rotate, write_rgb_rotate


class MethodLogger:
    def __init__(self, obj):
        self._obj = obj
        self._log = []

    def __getattr__(self, name):
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
            return functools.partial(self._method, name, value)
        else:
            self._log.append(("__getattr__", (name,), {}))
            return value

    def _method(self, name, meth, *args, **kwargs):
        self._log.append((name, args, kwargs))
        return meth(*args, **kwargs)

    def _filter(self, type_):
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

    def __init__(self, data):
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
    def name(self):
        return 123

    def seekable(self):
        return False

    def writable(self):
        return False


class WriteOnlyPipe(BytesIO):
    """
    Buffer which behaves like a writable pipe.
    """

    @property
    def name(self):
        return 123

    def readable(self):
        return False

    def seekable(self):
        return False


# Using a custom protocol will avoid the DASH muxer detecting or defaulting to a
# file: protocol and enabling the use of temporary files and renaming.
CUSTOM_IO_PROTOCOL = "pyavtest://"


class CustomIOLogger:
    """Log calls to open a file as well as method calls on the files"""

    def __init__(self):
        self._log = []
        self._method_log = []

    def __call__(self, *args, **kwargs):
        self._log.append((args, kwargs))
        self._method_log.append(self.io_open(*args, **kwargs))
        return self._method_log[-1]

    def io_open(self, url, flags, options):
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
    def test_basic_errors(self):
        self.assertRaises(Exception, av.open, None)
        self.assertRaises(Exception, av.open, None, "w")

    def test_reading_from_buffer(self):
        with open(fate_suite("mpeg2/mpeg2_field_encoding.ts"), "rb") as fh:
            buf = BytesIO(fh.read())
        self.read(buf, seekable=True)

    def test_reading_from_buffer_no_seek(self):
        with open(fate_suite("mpeg2/mpeg2_field_encoding.ts"), "rb") as fh:
            buf = ReadOnlyBuffer(fh.read())
        self.read(buf, seekable=False)

    def test_reading_from_file(self):
        with open(fate_suite("mpeg2/mpeg2_field_encoding.ts"), "rb") as fh:
            self.read(fh, seekable=True)

    def test_reading_from_pipe_readonly(self):
        with open(fate_suite("mpeg2/mpeg2_field_encoding.ts"), "rb") as fh:
            buf = ReadOnlyPipe(fh.read())
        self.read(buf, seekable=False)

    def test_reading_from_write_readonly(self):
        with open(fate_suite("mpeg2/mpeg2_field_encoding.ts"), "rb") as fh:
            buf = WriteOnlyPipe(fh.read())
        with self.assertRaises(ValueError) as cm:
            self.read(buf, seekable=False)

        assert (
            str(cm.exception)
            == "File object has no read() method, or readable() returned False."
        )

    def test_writing_to_buffer(self):
        buf = BytesIO()

        self.write(buf)

        # Check contents.
        self.assertTrue(buf.tell())
        buf.seek(0)
        with av.open(buf) as container:
            assert_rgb_rotate(self, container)

    def test_writing_to_buffer_broken(self):
        buf = BrokenBuffer()

        with self.assertRaises(OSError):
            with av.open(buf, "w", "mp4") as container:
                write_rgb_rotate(container)

                # break I/O
                buf.broken = True

    def test_writing_to_buffer_broken_with_close(self):
        buf = BrokenBuffer()

        with av.open(buf, "w", "mp4") as container:
            write_rgb_rotate(container)

            # break I/O
            buf.broken = True

            # try to close file
            with self.assertRaises(OSError):
                container.close()

    @run_in_sandbox
    def test_writing_to_custom_io_dash(self):
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
        self.assertGreaterEqual(len(wrapped_custom_io._log), 3)
        self.assertGreaterEqual(len(wrapped_custom_io._method_log), 3)

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

    def test_writing_to_custom_io_image2(self):
        if not has_pillow:
            raise SkipTest()

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

            for frame_i in range(frame_count):
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
            stream = container.streams[0]
            assert isinstance(stream, av.video.stream.VideoStream)
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
            self.write(fh)

        # Check contents.
        with av.open(path) as container:
            assert_rgb_rotate(self, container)

    def test_writing_to_pipe_readonly(self) -> None:
        buf = ReadOnlyPipe()
        with self.assertRaises(ValueError) as cm:
            self.write(buf)
        assert (
            str(cm.exception)
            == "File object has no write() method, or writable() returned False."
        )

    def test_writing_to_pipe_writeonly(self):
        av.logging.set_level(av.logging.VERBOSE)

        buf = WriteOnlyPipe()
        with self.assertRaises(ValueError) as cm:
            self.write(buf)
        assert "[mp4] muxer does not support non seekable output" in str(cm.exception)

        av.logging.set_level(None)

    def read(self, fh, seekable: bool = True) -> None:
        wrapped = MethodLogger(fh)

        with av.open(wrapped, "r") as container:
            assert container.format.name == "mpegts"
            self.assertEqual(
                container.format.long_name, "MPEG-TS (MPEG-2 Transport Stream)"
            )
            assert len(container.streams) == 1
            if seekable:
                assert container.size == 800000
            assert container.metadata == {}

        # Check method calls.
        self.assertTrue(wrapped._filter("read"))
        if seekable:
            self.assertTrue(wrapped._filter("seek"))

    def write(self, fh):
        wrapped = MethodLogger(fh)

        with av.open(wrapped, "w", "mp4") as container:
            write_rgb_rotate(container)

        # Check method calls.
        self.assertTrue(wrapped._filter("write"))
        self.assertTrue(wrapped._filter("seek"))
