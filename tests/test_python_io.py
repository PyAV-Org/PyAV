from io import BytesIO

import av

from .common import MethodLogger, TestCase, fate_suite
from .test_encode import assert_rgb_rotate, write_rgb_rotate


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
        fh = BytesIO()

        self.write(fh)

        # Check contents.
        self.assertTrue(fh.tell())
        fh.seek(0)
        assert_rgb_rotate(self, av.open(fh))

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
