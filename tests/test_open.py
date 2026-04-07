import gc
import io
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


def _container_no_close() -> None:
    buf = io.BytesIO()
    container = av.open(buf, mode="w", format="mp4")
    stream = container.add_stream("mpeg4", rate=24)
    stream.width = 320
    stream.height = 240
    stream.pix_fmt = "yuv420p"
    container.start_encoding()


def test_container_no_close() -> None:
    # Do not close so that container is freed through GC.
    _container_no_close()
    gc.collect()
