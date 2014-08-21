from .common import *

from av.subtitles.subtitle import *


class TestSubtitle(TestCase):

    def test_movtext(self):

        path = fate_suite('sub/MovText_capability_tester.mp4')

        fh = av.open(path)
        subs = []
        for packet in fh.demux():
            for frame in packet.decode():
                subs.append(frame)

        self.assertEqual(len(subs), 3)
        self.assertIsInstance(subs[0][0], AssSubtitle)
        self.assertEqual(subs[0][0].ass, 'Dialogue: 0,0:00:00.97,0:00:02.54,Default,- Test 1.\\N- Test 2.\r\n')

    def test_vobsub(self):

        path = fate_suite('sub/vobsub.sub')

        fh = av.open(path)
        subs = []
        for packet in fh.demux():
            for frame in packet.decode():
                subs.append(frame)

        self.assertEqual(len(subs), 43)

        sub = subs[0][0]
        self.assertIsInstance(sub, BitmapSubtitle)
        self.assertEqual(sub.x, 259)
        self.assertEqual(sub.y, 379)
        self.assertEqual(sub.width, 200)
        self.assertEqual(sub.height, 24)

        bms = sub.pict_buffers
        self.assertIsNone(bms[1])
        self.assertIsNone(bms[2])
        self.assertIsNone(bms[3])
        self.assertEqual(len(bms[0]), 4800)


