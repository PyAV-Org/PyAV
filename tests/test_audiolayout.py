from .common import *
from av.audio.layout import AudioLayout


class TestAudioLayout(TestCase):

    def test_stereo_properties(self):
        layout = AudioLayout('stereo')
        self._test_stereo(layout)

    def test_2channel_properties(self):
        layout = AudioLayout(2)
        self._test_stereo(layout)

    def test_channel_counts(self):
        self.assertRaises(ValueError, AudioLayout, -1)
        self.assertRaises(ValueError, AudioLayout, 9)
        
    def _test_stereo(self, layout):
        self.assertEqual(layout.name, 'stereo')
        self.assertEqual(len(layout.channels), 2)
        self.assertEqual(repr(layout), "<av.AudioLayout 'stereo'>")
        self.assertEqual(layout.channels[0].name, "FL")
        self.assertEqual(layout.channels[0].description, "front left")
        self.assertEqual(repr(layout.channels[0]), "<av.AudioChannel 'FL' (front left)>")
        self.assertEqual(layout.channels[1].name, "FR")
        self.assertEqual(layout.channels[1].description, "front right")
        self.assertEqual(repr(layout.channels[1]), "<av.AudioChannel 'FR' (front right)>")

    def test_defaults(self):
        for i, name in enumerate('''
            mono
            stereo
            2.1
            4.0
            5.0
            5.1
            6.1
            7.1
        '''.strip().split()):
            layout = AudioLayout(i + 1)
            self.assertEqual(layout.name, name)
            self.assertEqual(len(layout.channels), i + 1)
