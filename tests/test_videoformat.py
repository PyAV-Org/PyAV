from .common import *
from av.video.format import Descriptor


class TestVideoFormatDescriptor(TestCase):

    def test_rgb24_inspection(self):
        fmt = Descriptor('rgb24')
        self.assertEqual(fmt.name, 'rgb24')
        self.assertEqual(len(fmt.components), 3)
        self.assertFalse(fmt.is_planar)
        self.assertFalse(fmt.has_palette)
        self.assertTrue(fmt.is_rgb)
        self.assertEqual(fmt.chroma_width(1024), 1024)
        self.assertEqual(fmt.chroma_height(1024), 1024)
        for i in xrange(3):
            comp = fmt.components[i]
            self.assertEqual(comp.plane, 0)
            self.assertEqual(comp.bits, 8)

    def test_yuv420p_inspection(self):
        fmt = Descriptor('yuv420p')
        self.assertEqual(fmt.name, 'yuv420p')
        self.assertEqual(len(fmt.components), 3)
        self.assertTrue(fmt.is_planar)
        self.assertFalse(fmt.has_palette)
        self.assertFalse(fmt.is_rgb)
        self.assertEqual(fmt.chroma_width(1024), 512)
        self.assertEqual(fmt.chroma_height(1024), 512)
        for i in xrange(3):
            comp = fmt.components[i]
            self.assertEqual(comp.plane, i)
            self.assertEqual(comp.bits, 8)

    def test_gray16be_inspection(self):
        fmt = Descriptor('gray16be')
        self.assertEqual(fmt.name, 'gray16be')
        self.assertEqual(len(fmt.components), 1)
        self.assertFalse(fmt.is_planar)
        self.assertFalse(fmt.has_palette)
        self.assertFalse(fmt.is_rgb)
        self.assertEqual(fmt.chroma_width(1024), 1024)
        self.assertEqual(fmt.chroma_height(1024), 1024)
        comp = fmt.components[0]
        self.assertEqual(comp.plane, 0)
        self.assertEqual(comp.bits, 16)
