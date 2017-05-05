from common import *


class TestVideoCodecContext(TestCase):

    def setUp(self):
        fh = av.open(fate_png())
        for frame in fh.decode(video=0):
            self.frame = frame
            break
        self.yuv420p = frame.reformat(format='yuv420p')

    def test_encoding(self):
        ctx = Codec('mpeg4', 'w').create()
        ctx.format = self.yuv420p.format
        ctx.framerate = 24
        ctx.time_base = '1/24'
        print ctx.framerate
        print ctx.time_base
        ctx.open()
        packet = ctx.encode(self.yuv420p)
        if not packet:
            packet = ctx.encode(None)
        self.assertIsInstance(packet, Packet)

