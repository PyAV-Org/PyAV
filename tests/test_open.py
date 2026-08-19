import gc
import io
from pathlib import Path

import pytest

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


def test_output_container_is_closed_after_close(tmp_path) -> None:
    path = str(tmp_path / "out.mp4")
    container = av.open(path, "w")
    stream = container.add_stream("mpeg4", rate=24)
    stream.width = stream.height = 64
    stream.pix_fmt = "yuv420p"
    container.mux(stream.encode(av.VideoFrame(64, 64, "yuv420p")))
    container.mux(stream.encode(None))
    container.close()

    # Muxing has no avformat_close_input() to null the context for it, so
    # everything below used to keep working on a finished file.
    for call in (
        lambda: container.add_stream("mpeg4", rate=24),
        lambda: container.add_mux_stream("h264"),
        lambda: container.add_data_stream(),
        lambda: container.add_attachment("a", "text/plain", b"b"),
        lambda: container.supported_codecs,
        lambda: container.mux(av.Packet(4)),
        lambda: container.start_encoding(),
        lambda: container.dumps_format(),
    ):
        with pytest.raises(AssertionError, match="Container is not open"):
            call()

    container.close()  # idempotent
