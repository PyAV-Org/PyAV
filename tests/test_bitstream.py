import av
from av import Packet
from av.bitstream import BitStreamFilterContext, bitstream_filters_available

from .common import TestCase, fate_suite


class TestBitStreamFilters(TestCase):

    def test_filters_availible(self):
        self.assertIn("h264_mp4toannexb", bitstream_filters_available)

    def test_filter_chomp(self):
        ctx = BitStreamFilterContext("chomp")

        src_packets = [Packet(b"\x0012345\0\0\0"), None]
        self.assertEqual(bytes(src_packets[0]), b"\x0012345\0\0\0")

        result_packets = []
        for p in src_packets:
            result_packets.extend(ctx.filter(p))

        self.assertEqual(len(result_packets), 1)
        self.assertEqual(bytes(result_packets[0]), b"\x0012345")

    def test_filter_setts(self):
        ctx = BitStreamFilterContext("setts=pts=N")

        p1 = Packet(b"\0")
        p1.pts = 42
        p2 = Packet(b"\0")
        p2.pts = 50
        src_packets = [p1, p2, None]

        result_packets = []
        for p in src_packets:
            result_packets.extend(ctx.filter(p))

        self.assertEqual(len(result_packets), 2)
        self.assertEqual(result_packets[0].pts, 0)
        self.assertEqual(result_packets[1].pts, 1)

    def test_filter_h264_mp4toannexb(self):
        def is_annexb(packet):
            data = bytes(packet)
            return data[:3] == b"\0\0\x01" or data[:4] == b"\0\0\0\x01"

        with av.open(fate_suite("h264/interlaced_crop.mp4"), "r") as container:
            stream = container.streams.video[0]
            ctx = BitStreamFilterContext("h264_mp4toannexb", stream)

            res_packets = []
            for p in container.demux(stream):
                self.assertFalse(is_annexb(p))
                res_packets.extend(ctx.filter(p))

            self.assertEqual(len(res_packets), stream.frames)

            for p in res_packets:
                self.assertTrue(is_annexb(p))
