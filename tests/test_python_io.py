from io import BytesIO
from multiprocessing import Process
import os
import unittest

import av

from .common import MethodLogger, TestCase, fate_suite, is_windows
from .test_encode import assert_rgb_rotate, write_rgb_rotate


def feed_pipe(fd):
    with open(fate_suite("mpeg2/mpeg2_field_encoding.ts"), "rb") as fh:
        data = fh.read()
    with os.fdopen(fd, "wb") as fh:
        fh.write(data)


class NonSeekableBuffer:
    def __init__(self, data):
        self.data = data

    def read(self, n):
        data = self.data[0:n]
        self.data = self.data[n:]
        return data


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
            buf = NonSeekableBuffer(fh.read())
            self.read(buf, seekable=False)

    def test_reading_from_file(self):
        with open(fate_suite("mpeg2/mpeg2_field_encoding.ts"), "rb") as fh:
            self.read(fh, seekable=True)

    @unittest.skipIf(is_windows, "The Process hangs on Windows")
    def test_reading_from_pipe(self):
        read_fd, write_fd = os.pipe()

        p = Process(target=feed_pipe, args=(write_fd,))
        p.start()

        with os.fdopen(read_fd, "rb") as fh:
            self.read(fh, seekable=False)

        p.terminate()
        p.join()

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
