import av

from .common import TestCase, fate_suite


class TestProperties(TestCase):
    def test_is_keyframe(self):
        with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
            stream = container.streams.video[0]
            for i, packet in enumerate(container.demux(stream)):
                if i in (0, 21, 45, 69, 93, 117):
                    self.assertTrue(packet.is_keyframe)
                else:
                    self.assertFalse(packet.is_keyframe)

    def test_is_corrupt(self):
        with av.open(fate_suite("mov/white_zombie_scrunch-part.mov")) as container:
            stream = container.streams.video[0]
            for i, packet in enumerate(container.demux(stream)):
                if i == 65:
                    self.assertTrue(packet.is_corrupt)
                else:
                    self.assertFalse(packet.is_corrupt)

    def test_is_discard(self):
        with av.open(fate_suite("mov/mov-1elist-ends-last-bframe.mov")) as container:
            stream = container.streams.video[0]
            for i, packet in enumerate(container.demux(stream)):
                if i == 46:
                    self.assertTrue(packet.is_discard)
                else:
                    self.assertFalse(packet.is_discard)

    def test_is_disposable(self):
        with av.open(fate_suite("hap/HAPQA_NoSnappy_127x1.mov")) as container:
            stream = container.streams.video[0]
            for i, packet in enumerate(container.demux(stream)):
                if i == 0:
                    self.assertTrue(packet.is_disposable)
                else:
                    self.assertFalse(packet.is_disposable)

    def test_set_duration(self):
        with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
            for packet in container.demux():
                old_duration = packet.duration
                packet.duration += 10

                self.assertEqual(packet.duration, old_duration + 10)
