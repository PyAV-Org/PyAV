from av import ContainerFormat, formats_available

from .common import TestCase


class TestContainerFormats(TestCase):
    def test_matroska(self):
        fmt = ContainerFormat("matroska")
        self.assertTrue(fmt.is_input)
        self.assertTrue(fmt.is_output)
        self.assertEqual(fmt.name, "matroska")
        self.assertEqual(fmt.long_name, "Matroska")
        self.assertIn("mkv", fmt.extensions)
        self.assertFalse(fmt.no_file)

    def test_mov(self):
        fmt = ContainerFormat("mov")
        self.assertTrue(fmt.is_input)
        self.assertTrue(fmt.is_output)
        self.assertEqual(fmt.name, "mov")
        self.assertEqual(fmt.long_name, "QuickTime / MOV")
        self.assertIn("mov", fmt.extensions)
        self.assertFalse(fmt.no_file)

    def test_stream_segment(self):
        # This format goes by two names, check both.
        fmt = ContainerFormat("stream_segment")
        self.assertFalse(fmt.is_input)
        self.assertTrue(fmt.is_output)
        self.assertEqual(fmt.name, "stream_segment")
        self.assertEqual(fmt.long_name, "streaming segment muxer")
        self.assertEqual(fmt.extensions, set())
        self.assertTrue(fmt.no_file)

        fmt = ContainerFormat("ssegment")
        self.assertFalse(fmt.is_input)
        self.assertTrue(fmt.is_output)
        self.assertEqual(fmt.name, "ssegment")
        self.assertEqual(fmt.long_name, "streaming segment muxer")
        self.assertEqual(fmt.extensions, set())
        self.assertTrue(fmt.no_file)

    def test_formats_available(self):
        self.assertTrue(formats_available)
