from pathlib import Path

import av

from .common import TestCase, fate_suite


class TestOpen(TestCase):
    def test_path_input(self):
        path = Path(fate_suite("h264/interlaced_crop.mp4"))
        self.assertIsInstance(path, Path)

        container = av.open(path)
        self.assertIs(type(container), av.container.InputContainer)

    def test_str_input(self):
        path = fate_suite("h264/interlaced_crop.mp4")
        self.assertIs(type(path), str)

        container = av.open(path)
        self.assertIs(type(container), av.container.InputContainer)

    def test_path_output(self):
        path = Path(fate_suite("h264/interlaced_crop.mp4"))
        self.assertIsInstance(path, Path)

        container = av.open(path, "w")
        self.assertIs(type(container), av.container.OutputContainer)

    def test_str_output(self):
        path = fate_suite("h264/interlaced_crop.mp4")
        self.assertIs(type(path), str)

        container = av.open(path, "w")
        self.assertIs(type(container), av.container.OutputContainer)
