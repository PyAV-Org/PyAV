from io import BytesIO

import av

from .common import MethodLogger, TestCase, fate_suite
from .test_encode import assert_rgb_rotate, write_rgb_rotate


class NonSeekableBuffer:
    def __init__(self, data):
        self.data = data

    def read(self, n):
        data = self.data[0:n]
        self.data = self.data[n:]
        return data


class TestPythonIO(TestCase):
    def test_reading(self):

        with open(fate_suite("mpeg2/mpeg2_field_encoding.ts"), "rb") as fh:
            wrapped = MethodLogger(fh)

            container = av.open(wrapped)

            self.assertEqual(container.format.name, "mpegts")
            self.assertEqual(
                container.format.long_name, "MPEG-TS (MPEG-2 Transport Stream)"
            )
            self.assertEqual(len(container.streams), 1)
            self.assertEqual(container.size, 800000)
            self.assertEqual(container.metadata, {})

            # Make sure it did actually call "read".
            reads = wrapped._filter("read")
            self.assertTrue(reads)

    def test_reading_no_seek(self):
        with open(fate_suite("mpeg2/mpeg2_field_encoding.ts"), "rb") as fh:
            data = fh.read()

        buf = NonSeekableBuffer(data)
        wrapped = MethodLogger(buf)

        container = av.open(wrapped)

        self.assertEqual(container.format.name, "mpegts")
        self.assertEqual(
            container.format.long_name, "MPEG-TS (MPEG-2 Transport Stream)"
        )
        self.assertEqual(len(container.streams), 1)
        self.assertEqual(container.metadata, {})

        # Make sure it did actually call "read".
        reads = wrapped._filter("read")
        self.assertTrue(reads)

    def test_basic_errors(self):
        self.assertRaises(Exception, av.open, None)
        self.assertRaises(Exception, av.open, None, "w")

    def test_writing(self):

        path = self.sandboxed("writing.mov")
        with open(path, "wb") as fh:
            wrapped = MethodLogger(fh)

            output = av.open(wrapped, "w", "mov")
            write_rgb_rotate(output)
            output.close()
            fh.close()

            # Make sure it did actually write.
            writes = wrapped._filter("write")
            self.assertTrue(writes)

            # Standard assertions.
            assert_rgb_rotate(self, av.open(path))

    def test_buffer_read_write(self):

        buffer_ = BytesIO()
        wrapped = MethodLogger(buffer_)
        write_rgb_rotate(av.open(wrapped, "w", "mp4"))

        # Make sure it did actually write.
        writes = wrapped._filter("write")
        self.assertTrue(writes)

        self.assertTrue(buffer_.tell())

        # Standard assertions.
        buffer_.seek(0)
        assert_rgb_rotate(self, av.open(buffer_))
