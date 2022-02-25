from av import VideoFormat

from .common import TestCase


class TestVideoFormats(TestCase):
    def test_invalid_pixel_format(self):
        with self.assertRaises(ValueError) as cm:
            VideoFormat("__unknown_pix_fmt", 640, 480)
        self.assertEqual(str(cm.exception), "not a pixel format: '__unknown_pix_fmt'")

    def test_rgb24_inspection(self):
        fmt = VideoFormat("rgb24", 640, 480)
        self.assertEqual(fmt.name, "rgb24")
        self.assertEqual(len(fmt.components), 3)
        self.assertFalse(fmt.is_planar)
        self.assertFalse(fmt.has_palette)
        self.assertTrue(fmt.is_rgb)
        self.assertEqual(fmt.chroma_width(), 640)
        self.assertEqual(fmt.chroma_height(), 480)
        self.assertEqual(fmt.chroma_width(1024), 1024)
        self.assertEqual(fmt.chroma_height(1024), 1024)
        for i in range(3):
            comp = fmt.components[i]
            self.assertEqual(comp.plane, 0)
            self.assertEqual(comp.bits, 8)
            self.assertFalse(comp.is_luma)
            self.assertFalse(comp.is_chroma)
            self.assertFalse(comp.is_alpha)
            self.assertEqual(comp.width, 640)
            self.assertEqual(comp.height, 480)

    def test_yuv420p_inspection(self):
        fmt = VideoFormat("yuv420p", 640, 480)
        self.assertEqual(fmt.name, "yuv420p")
        self.assertEqual(len(fmt.components), 3)
        self._test_yuv420(fmt)

    def _test_yuv420(self, fmt):
        self.assertTrue(fmt.is_planar)
        self.assertFalse(fmt.has_palette)
        self.assertFalse(fmt.is_rgb)
        self.assertEqual(fmt.chroma_width(), 320)
        self.assertEqual(fmt.chroma_height(), 240)
        self.assertEqual(fmt.chroma_width(1024), 512)
        self.assertEqual(fmt.chroma_height(1024), 512)
        for i, comp in enumerate(fmt.components):
            comp = fmt.components[i]
            self.assertEqual(comp.plane, i)
            self.assertEqual(comp.bits, 8)
        self.assertFalse(fmt.components[0].is_chroma)
        self.assertTrue(fmt.components[1].is_chroma)
        self.assertTrue(fmt.components[2].is_chroma)
        self.assertTrue(fmt.components[0].is_luma)
        self.assertFalse(fmt.components[1].is_luma)
        self.assertFalse(fmt.components[2].is_luma)
        self.assertFalse(fmt.components[0].is_alpha)
        self.assertFalse(fmt.components[1].is_alpha)
        self.assertFalse(fmt.components[2].is_alpha)
        self.assertEqual(fmt.components[0].width, 640)
        self.assertEqual(fmt.components[1].width, 320)
        self.assertEqual(fmt.components[2].width, 320)

    def test_yuva420p_inspection(self):
        fmt = VideoFormat("yuva420p", 640, 480)
        self.assertEqual(len(fmt.components), 4)
        self._test_yuv420(fmt)
        self.assertFalse(fmt.components[3].is_chroma)
        self.assertEqual(fmt.components[3].width, 640)

    def test_gray16be_inspection(self):
        fmt = VideoFormat("gray16be", 640, 480)
        self.assertEqual(fmt.name, "gray16be")
        self.assertEqual(len(fmt.components), 1)
        self.assertFalse(fmt.is_planar)
        self.assertFalse(fmt.has_palette)
        self.assertFalse(fmt.is_rgb)
        self.assertEqual(fmt.chroma_width(), 640)
        self.assertEqual(fmt.chroma_height(), 480)
        self.assertEqual(fmt.chroma_width(1024), 1024)
        self.assertEqual(fmt.chroma_height(1024), 1024)
        comp = fmt.components[0]
        self.assertEqual(comp.plane, 0)
        self.assertEqual(comp.bits, 16)
        self.assertTrue(comp.is_luma)
        self.assertFalse(comp.is_chroma)
        self.assertEqual(comp.width, 640)
        self.assertEqual(comp.height, 480)
        self.assertFalse(comp.is_alpha)

    def test_pal8_inspection(self):
        fmt = VideoFormat("pal8", 640, 480)
        self.assertEqual(len(fmt.components), 1)
        self.assertTrue(fmt.has_palette)
