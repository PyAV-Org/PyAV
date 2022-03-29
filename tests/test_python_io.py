from io import BytesIO

import av

from .common import MethodLogger, TestCase, fate_suite, run_in_directory
from .test_encode import assert_rgb_rotate, write_rgb_rotate


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


CUSTOM_IO_PROTOCOL = "pyavtest://"
CUSTOM_IO_FILENAME = "custom_io_output.mpd"


class CustomIOLogger(object):
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
            raise RuntimeError("Unsupported io open mode {}".format(flags))

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
        self.assertEqual(
            str(cm.exception),
            "File object has no read() method, or readable() returned False.",
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

    def test_writing_to_custom_io(self):

        # Run the test in the sandbox directory to workaround the limitation of the DASH demuxer
        # whe dealing with relative files in the manifest.
        with run_in_directory(self.sandbox):
            # Custom I/O that opens file and logs calls
            wrapped_custom_io = CustomIOLogger()

            # Write a DASH package using the custom IO
            with av.open(
                CUSTOM_IO_PROTOCOL + CUSTOM_IO_FILENAME, "w", io_open=wrapped_custom_io
            ) as container:
                write_rgb_rotate(container)

            # Check that at least 3 files were opened using the custom IO:
            #   "CUSTOM_IO_FILENAME", init-stream0.m4s and chunk-stream-0x.m4s
            self.assertGreaterEqual(len(wrapped_custom_io._log), 3)
            self.assertGreaterEqual(len(wrapped_custom_io._method_log), 3)

            # Check that all files were written to
            all_write = all(
                method_log._filter("write") for method_log in wrapped_custom_io._method_log
            )
            self.assertTrue(all_write)

            # Check that all files were closed
            all_closed = all(
                method_log._filter("close") for method_log in wrapped_custom_io._method_log
            )
            self.assertTrue(all_closed)

            # Check contents.
            # Note that the dash demuxer doesn't support custom I/O.
            with av.open(CUSTOM_IO_FILENAME, "r") as container:
                assert_rgb_rotate(self, container)

    def test_writing_to_file(self):
        path = self.sandboxed("writing.mp4")

        with open(path, "wb") as fh:
            self.write(fh)

        # Check contents.
        with av.open(path) as container:
            assert_rgb_rotate(self, container)

    def test_writing_to_pipe_readonly(self):
        buf = ReadOnlyPipe()
        with self.assertRaises(ValueError) as cm:
            self.write(buf)
        self.assertEqual(
            str(cm.exception),
            "File object has no write() method, or writable() returned False.",
        )

    def test_writing_to_pipe_writeonly(self):
        buf = WriteOnlyPipe()
        with self.assertRaises(ValueError) as cm:
            self.write(buf)
        self.assertIn(
            "[mp4] muxer does not support non seekable output",
            str(cm.exception),
        )

    def read(self, fh, seekable=True):
        wrapped = MethodLogger(fh)

        with av.open(wrapped) as container:
            self.assertEqual(container.format.name, "mpegts")
            self.assertEqual(
                container.format.long_name, "MPEG-TS (MPEG-2 Transport Stream)"
            )
            self.assertEqual(len(container.streams), 1)
            if seekable:
                self.assertEqual(container.size, 800000)
            self.assertEqual(container.metadata, {})

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
