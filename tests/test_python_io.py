from .common import *


class TestPythonIO(TestCase):

    def test_reading(self):

        fh = open(fate_suite('mpeg2/mpeg2_field_encoding.ts'), 'rb')
        container = av.open(fh)

        self.assertEqual(container.format.name, 'mpegts')
        self.assertEqual(container.format.long_name, "MPEG-TS (MPEG-2 Transport Stream)")
        self.assertEqual(len(container.streams), 1)
        self.assertEqual(container.size, 800000)
        self.assertEqual(container.metadata, {})

