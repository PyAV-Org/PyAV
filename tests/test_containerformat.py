from av import ContainerFormat, formats_available, open

from .common import TestCase


class TestContainerFormats(TestCase):
    def test_matroska(self) -> None:
        with open("test.mkv", "w") as container:
            self.assertNotEqual(container.default_video_codec, "none")
            self.assertNotEqual(container.default_audio_codec, "none")
            self.assertEqual(container.default_subtitle_codec, "ass")
            self.assertIn("ass", container.supported_codecs)

        fmt = ContainerFormat("matroska")
        self.assertTrue(fmt.is_input)
        self.assertTrue(fmt.is_output)
        self.assertEqual(fmt.name, "matroska")
        self.assertEqual(fmt.long_name, "Matroska")
        self.assertIn("mkv", fmt.extensions)
        self.assertFalse(fmt.no_file)

    def test_mov(self) -> None:
        with open("test.mov", "w") as container:
            self.assertNotEqual(container.default_video_codec, "none")
            self.assertNotEqual(container.default_audio_codec, "none")
            self.assertEqual(container.default_subtitle_codec, "none")
            self.assertIn("h264", container.supported_codecs)

        fmt = ContainerFormat("mov")
        self.assertTrue(fmt.is_input)
        self.assertTrue(fmt.is_output)
        self.assertEqual(fmt.name, "mov")
        self.assertEqual(fmt.long_name, "QuickTime / MOV")
        self.assertIn("mov", fmt.extensions)
        self.assertFalse(fmt.no_file)

    def test_gif(self) -> None:
        with open("test.gif", "w") as container:
            self.assertEqual(container.default_video_codec, "gif")
            self.assertEqual(container.default_audio_codec, "none")
            self.assertEqual(container.default_subtitle_codec, "none")
            self.assertIn("gif", container.supported_codecs)

    def test_stream_segment(self) -> None:
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

    def test_formats_available(self) -> None:
        self.assertTrue(formats_available)
