from av import AudioLayout

from .common import TestCase


class TestAudioLayout(TestCase):
    def test_stereo_from_str(self):
        layout = AudioLayout("stereo")
        self._test_stereo(layout)

    def test_stereo_from_layout(self):
        layout = AudioLayout("stereo")
        layout2 = AudioLayout(layout)
        self._test_stereo(layout2)

    def _test_stereo(self, layout):
        self.assertEqual(layout.name, "stereo")
        self.assertEqual(layout.nb_channels, 2)
        self.assertEqual(repr(layout), "<av.AudioLayout 'stereo'>")
        # self.assertEqual(layout.channels[0].name, "FL")
        # self.assertEqual(layout.channels[0].description, "front left")
        # self.assertEqual(
        #     repr(layout.channels[0]), "<av.AudioChannel 'FL' (front left)>"
        # )
        # self.assertEqual(layout.channels[1].name, "FR")
        # self.assertEqual(layout.channels[1].description, "front right")
        # self.assertEqual(
        #     repr(layout.channels[1]), "<av.AudioChannel 'FR' (front right)>"
        # )
