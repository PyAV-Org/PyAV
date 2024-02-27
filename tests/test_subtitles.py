import av
from av.subtitles.subtitle import AssSubtitle, BitmapSubtitle

from .common import TestCase, fate_suite


class TestSubtitle(TestCase):
    def test_movtext(self):
        path = fate_suite("sub/MovText_capability_tester.mp4")

        subs = []
        with av.open(path) as container:
            for packet in container.demux():
                subs.extend(packet.decode())

        self.assertEqual(len(subs), 3)

        subset = subs[0]
        self.assertEqual(subset.format, 1)
        self.assertEqual(subset.pts, 970000)
        self.assertEqual(subset.start_display_time, 0)
        self.assertEqual(subset.end_display_time, 1570)

        sub = subset[0]
        self.assertIsInstance(sub, AssSubtitle)
        self.assertEqual(sub.ass, "0,0,Default,,0,0,0,,- Test 1.\\N- Test 2.")

    def test_vobsub(self):
        path = fate_suite("sub/vobsub.sub")

        subs = []
        with av.open(path) as container:
            for packet in container.demux():
                subs.extend(packet.decode())

        self.assertEqual(len(subs), 43)

        subset = subs[0]
        self.assertEqual(subset.format, 0)
        self.assertEqual(subset.pts, 132499044)
        self.assertEqual(subset.start_display_time, 0)
        self.assertEqual(subset.end_display_time, 4960)

        sub = subset[0]
        self.assertIsInstance(sub, BitmapSubtitle)
        self.assertEqual(sub.x, 259)
        self.assertEqual(sub.y, 379)
        self.assertEqual(sub.width, 200)
        self.assertEqual(sub.height, 24)

        bms = sub.planes
        self.assertEqual(len(bms), 1)
        self.assertEqual(len(memoryview(bms[0])), 4800)
