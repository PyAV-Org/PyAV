from av import VideoFormat

from .common import TestCase


class TestVideoFormats(TestCase):
    def test_invalid_pixel_format(self):
        with self.assertRaises(ValueError) as cm:
            VideoFormat("__unknown_pix_fmt", 640, 480)
        assert str(cm.exception) == "not a pixel format: '__unknown_pix_fmt'"

    def test_rgb24_inspection(self) -> None:
        fmt = VideoFormat("rgb24", 640, 480)
        assert fmt.name == "rgb24"
        assert len(fmt.components) == 3
        assert not fmt.is_planar
        assert not fmt.has_palette
        assert fmt.is_rgb
        assert fmt.chroma_width() == 640
        assert fmt.chroma_height() == 480
        assert fmt.chroma_width(1024) == 1024
        assert fmt.chroma_height(1024) == 1024
        for i in range(3):
            comp = fmt.components[i]
            assert comp.plane == 0
            assert comp.bits == 8
            assert not comp.is_luma
            assert not comp.is_chroma
            assert not comp.is_alpha
            assert comp.width == 640
            assert comp.height == 480

    def test_yuv420p_inspection(self) -> None:
        fmt = VideoFormat("yuv420p", 640, 480)
        assert fmt.name == "yuv420p"
        assert len(fmt.components) == 3
        self._test_yuv420(fmt)

    def _test_yuv420(self, fmt: VideoFormat) -> None:
        assert fmt.is_planar
        assert not fmt.has_palette
        assert not fmt.is_rgb
        assert fmt.chroma_width() == 320
        assert fmt.chroma_height() == 240
        assert fmt.chroma_width(1024) == 512
        assert fmt.chroma_height(1024) == 512
        for i, comp in enumerate(fmt.components):
            comp = fmt.components[i]
            assert comp.plane == i
            assert comp.bits == 8
        assert not fmt.components[0].is_chroma
        assert fmt.components[1].is_chroma
        assert fmt.components[2].is_chroma
        assert fmt.components[0].is_luma
        assert not fmt.components[1].is_luma
        assert not fmt.components[2].is_luma
        assert not fmt.components[0].is_alpha
        assert not fmt.components[1].is_alpha
        assert not fmt.components[2].is_alpha
        assert fmt.components[0].width == 640
        assert fmt.components[1].width == 320
        assert fmt.components[2].width == 320

    def test_yuva420p_inspection(self) -> None:
        fmt = VideoFormat("yuva420p", 640, 480)
        assert len(fmt.components) == 4
        self._test_yuv420(fmt)
        assert not fmt.components[3].is_chroma
        assert fmt.components[3].width == 640

    def test_gray16be_inspection(self) -> None:
        fmt = VideoFormat("gray16be", 640, 480)
        assert fmt.name == "gray16be"
        assert len(fmt.components) == 1
        assert not fmt.is_planar
        assert not fmt.has_palette
        assert not fmt.is_rgb
        assert fmt.chroma_width() == 640
        assert fmt.chroma_height() == 480
        assert fmt.chroma_width(1024) == 1024
        assert fmt.chroma_height(1024) == 1024
        comp = fmt.components[0]
        assert comp.plane == 0
        assert comp.bits == 16
        assert comp.is_luma
        assert not comp.is_chroma
        assert comp.width == 640
        assert comp.height == 480
        assert not comp.is_alpha

    def test_pal8_inspection(self) -> None:
        fmt = VideoFormat("pal8", 640, 480)
        assert len(fmt.components) == 1
        assert fmt.has_palette
