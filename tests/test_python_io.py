from __future__ import division

import math
try:
    from cStringIO import StringIO
except ImportError:
    from io import BytesIO as StringIO

from .common import *
from .test_encoding import write_rgb_rotate, assert_rgb_rotate
from av.video.stream import VideoStream




class TestPythonIO(TestCase):

    def test_reading(self):

        fh = open(fate_suite('mpeg2/mpeg2_field_encoding.ts'), 'rb')
        wrapped = MethodLogger(fh)

        container = av.open(wrapped)

        self.assertEqual(container.format.name, 'mpegts')
        self.assertEqual(container.format.long_name, "MPEG-TS (MPEG-2 Transport Stream)")
        self.assertEqual(len(container.streams), 1)
        self.assertEqual(container.size, 800000)
        self.assertEqual(container.metadata, {})

        # Make sure it did actually call "read".
        reads = wrapped._filter('read')
        self.assertTrue(reads)

    def test_basic_errors(self):
        self.assertRaises(Exception, av.open, None)
        self.assertRaises(Exception, av.open, None, 'w')

    def test_writing(self):

        path = self.sandboxed('writing.mov')
        fh = open(path, 'wb')
        wrapped = MethodLogger(fh)

        output = av.open(wrapped, 'w')
        write_rgb_rotate(output)

        # Make sure it did actually write.
        writes = wrapped._filter('write')
        self.assertTrue(writes)

        # Standard assertions.
        assert_rgb_rotate(self, av.open(path))

    def test_buffer_read_write(self):

        buffer_ = StringIO()
        wrapped = MethodLogger(buffer_)
        write_rgb_rotate(av.open(wrapped, 'w', 'mp4'))

        # Make sure it did actually write.
        writes = wrapped._filter('write')
        self.assertTrue(writes)

        self.assertTrue(buffer_.tell())
        
        # Standard assertions.
        buffer_.seek(0)
        assert_rgb_rotate(self, av.open(buffer_))



