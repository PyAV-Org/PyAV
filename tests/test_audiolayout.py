from .common import *
from av.audio.layout import AudioLayout


class TestAudioLayout(TestCase):

    def test_stereo_properties(self):
        layout = AudioLayout('stereo')
        self.assertEqual(layout.name, 'stereo')
        self.assertEqual(len(layout.channels), 2)
        self.assertEqual(repr(layout), "<av.audio.AudioLayout 'stereo'>")
        self.assertEqual(layout.channels[0].name, "FL")
        self.assertEqual(layout.channels[0].description, "front left")
        self.assertEqual(repr(layout.channels[0]), "<av.audio.AudioChannel 'FL' (front left)>")
        self.assertEqual(layout.channels[1].name, "FR")
        self.assertEqual(layout.channels[1].description, "front right")
        self.assertEqual(repr(layout.channels[1]), "<av.audio.AudioChannel 'FR' (front right)>")

