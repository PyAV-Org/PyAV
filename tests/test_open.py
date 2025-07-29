from pathlib import Path

import av

from .common import fate_suite


def test_path_input() -> None:
    path = Path(fate_suite("h264/interlaced_crop.mp4"))
    assert isinstance(path, Path)

    container = av.open(path)
    assert type(container) is av.container.InputContainer


def test_str_input() -> None:
    path = fate_suite("h264/interlaced_crop.mp4")
    assert type(path) is str

    container = av.open(path)
    assert type(container) is av.container.InputContainer


def test_path_output() -> None:
    path = Path(fate_suite("h264/interlaced_crop.mp4"))
    assert isinstance(path, Path)

    container = av.open(path, "w")
    assert type(container) is av.container.OutputContainer


def test_str_output() -> None:
    path = fate_suite("h264/interlaced_crop.mp4")
    assert type(path) is str

    container = av.open(path, "w")
    assert type(container) is av.container.OutputContainer
