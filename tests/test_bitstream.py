from av import Packet
from av.bitstream import (BitStreamFilter, BitStreamFilterContext,
                          UnknownFilterError, bitstream_filters_availible)

from .common import TestCase


class TestBitStreamFilters(TestCase):

    def test_filters_availible(self):
        self.assertIn('h264_mp4toannexb', bitstream_filters_availible)

    def test_filter_bogus(self):
        with self.assertRaises(UnknownFilterError):
            BitStreamFilter('bogus123')

    def test_filter_h264_mp4toannexb(self):

        f = BitStreamFilter('h264_mp4toannexb')

        self.assertEqual(f.name, 'h264_mp4toannexb')

    def test_filter_chomp(self):

        f = BitStreamFilter('chomp')
        self.assertEqual(f.name, 'chomp')

        ctx = f.create()
        self.assert_filter_chomp(ctx)

    def test_filtercontext_chomp(self):
        ctx = BitStreamFilterContext('chomp')
        self.assert_filter_chomp(ctx)

    def assert_filter_chomp(self, ctx):

        p = Packet(b'\x0012345\0\0\0')
        self.assertEqual(p.to_bytes(), b'\x0012345\0\0\0')

        ps = ctx(p)
        self.assertEqual(len(ps), 1)
        p = ps[0]
        self.assertEqual(p.to_bytes(), b'\x0012345')
