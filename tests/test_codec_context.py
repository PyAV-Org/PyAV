from common import *


class TestVideoCodecContext(TestCase):

    def setUp(self):
        fh = av.open(fate_png())
        for frame in fh.decode(video=0):
            self.frame = frame
            break
        self.yuv420p = frame.reformat(format='yuv420p')

    def test_round_trip(self):

        print 'START OF TEST'

        ctx = Codec('mpeg4', 'w').create()
        ctx.format = self.yuv420p.format
        ctx.time_base = '1/24'

        ctx.open()
        packets = [ctx.encode(self.yuv420p)]
        packet = ctx.encode(None)
        ctx.close()

        while packet:
            packets.append(packet)
            packet = ctx.encode(None)

        print packets
        self.assertEqual(len(packets), 1)

        packet = Packet(packets[0]) # Wipe out context.
        print packet

        ctx = Codec('mpeg4', 'r').create()
        ctx.format = self.yuv420p.format
        ctx.time_base = '1/24'

        ctx.open()
        frames = ctx.decode(packet)
        frames.extend(ctx.decode(None))
        ctx.close()
        frames.extend(ctx.decode(None))

        self.assertEqual(len(frames), 1)
        self.assertIsInstance(frames[0], VideoFrame)
