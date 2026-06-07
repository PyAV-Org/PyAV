from __future__ import annotations

import io
import struct
from typing import cast

import numpy as np
import pytest

import av
from av.sidedata.sidedata import SideData
from av.video.stream import VideoStream

WIDTH = 320
HEIGHT = 240
DURATION = 10

# The 8 EXIF orientations as 3x3 transformation matrices, built the same way as
# the application code: a 90 deg rotation generator (R) and a horizontal-flip
# generator (F). Orientations 2, 4, 5, 7 are reflections, which a scalar
# rotation cannot represent -- so these are verified by comparing the full
# matrix that round-trips through the container.
_R = np.asarray([[0, -1, 0], [1, 0, 0], [0, 0, 1]], dtype=float)  # exif 8
_F = np.asarray([[-1, 0, 0], [0, 1, 0], [0, 0, 1]], dtype=float)  # exif 2

EXIF_MATRICES = {
    1: np.eye(3),
    2: _F,
    3: _R @ _R,
    4: _F @ _R @ _R,
    5: _F @ _R @ _R @ _R,
    6: _R @ _R @ _R,
    7: _F @ _R,
    8: _R,
}

# Pure-rotation orientations also have a well-defined scalar rotation, reported
# by av_display_rotation_get() (counter-clockwise, range [-180, 180]).
EXPECTED_ROTATION = {1: 0, 3: 180, 6: -90, 8: 90}

# Each EXIF orientation expressed through the convenience API as
# (degrees_ccw, hflip, vflip). Verified to reproduce EXIF_MATRICES exactly.
EXIF_VIA_ROTATION = {
    1: (0, False, False),
    2: (0, True, False),
    3: (0, True, True),
    4: (0, False, True),
    5: (90, True, False),
    6: (90, True, True),
    7: (90, False, True),
    8: (90, False, False),
}

# One encoder per codec family we care about, plus the near-universal mpeg4
# baseline. Unavailable encoders are skipped at runtime so the suite stays
# portable across FFmpeg builds.
CODECS = ["mpeg4", "libx264", "libopenh264", "libx265", "libsvtav1", "libaom-av1"]


def matrix_to_ints(matrix: np.ndarray) -> list[int]:
    """Convert a 3x3 matrix to FFmpeg's AV_PKT_DATA_DISPLAYMATRIX integers.

    Layout (a, b, u, c, d, v, x, y, w): 16.16 fixed point everywhere except
    u, v, w (indices 2, 5, 8) which are 2.30.
    """
    flat = [float(v) for v in matrix.reshape(-1)]
    return [
        int(round(v * (1 << 30))) if i in (2, 5, 8) else int(round(v * (1 << 16)))
        for i, v in enumerate(flat)
    ]


def _has_encoder(name: str) -> bool:
    try:
        av.codec.Codec(name, "w")
    except Exception:
        return False
    return True


def _encode(codec_name: str, matrix: list[int] | None) -> io.BytesIO:
    buf = io.BytesIO()
    container = av.open(buf, "w", format="mp4")
    stream = cast(VideoStream, container.add_stream(codec_name, rate=24))
    stream.width = WIDTH
    stream.height = HEIGHT
    stream.pix_fmt = "yuv420p"

    if matrix is not None:
        stream.set_display_matrix(matrix)

    for i in range(DURATION):
        img = np.full((HEIGHT, WIDTH, 3), (i * 8) % 256, dtype=np.uint8)
        frame = av.VideoFrame.from_ndarray(img, format="rgb24")
        for packet in stream.encode(frame):
            container.mux(packet)
    for packet in stream.encode():
        container.mux(packet)
    container.close()

    buf.seek(0)
    return buf


def _read_frame(buf: io.BytesIO) -> av.VideoFrame:
    with av.open(buf, "r", format="mp4") as container:
        return next(container.decode(video=0))


def _read_matrix(frame: av.VideoFrame) -> list[int] | None:
    sd = frame.side_data.get("DISPLAYMATRIX")
    if sd is None:
        return None
    return list(struct.unpack("=9i", bytes(cast(SideData, sd))))


@pytest.mark.parametrize("codec_name", CODECS)
@pytest.mark.parametrize("orientation", sorted(EXIF_MATRICES))
def test_exif_orientation_roundtrip(codec_name: str, orientation: int) -> None:
    if not _has_encoder(codec_name):
        pytest.skip(f"encoder {codec_name} not available")

    expected = matrix_to_ints(EXIF_MATRICES[orientation])
    frame = _read_frame(_encode(codec_name, expected))
    got = _read_matrix(frame)

    identity = matrix_to_ints(np.eye(3))
    if expected == identity:
        # Identity is the container default; demuxers emit no side data for it.
        assert got is None
        assert frame.rotation == 0
    else:
        assert got == expected, f"exif {orientation}: wrote {expected}, read {got}"

    if orientation in EXPECTED_ROTATION:
        rotation = frame.rotation
        # 180 may come back negated; rotations are exact otherwise.
        if abs(EXPECTED_ROTATION[orientation]) == 180:
            assert abs(rotation) == 180
        else:
            assert rotation == EXPECTED_ROTATION[orientation]


@pytest.mark.parametrize("degrees,expected", [(0, 0), (90, 90), (180, 180), (270, -90)])
def test_set_display_rotation_roundtrip(degrees: int, expected: int) -> None:
    # The public angle is counter-clockwise, matching VideoFrame.rotation.
    buf = io.BytesIO()
    container = av.open(buf, "w", format="mp4")
    stream = container.add_stream("mpeg4", rate=24)
    stream.width = WIDTH
    stream.height = HEIGHT
    stream.pix_fmt = "yuv420p"
    stream.set_display_rotation(degrees)
    for i in range(DURATION):
        frame = av.VideoFrame.from_ndarray(
            np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8), format="rgb24"
        )
        for packet in stream.encode(frame):
            container.mux(packet)
    for packet in stream.encode():
        container.mux(packet)
    container.close()

    buf.seek(0)
    rotation = _read_frame(buf).rotation
    if abs(expected) == 180:
        assert abs(rotation) == 180
    else:
        assert rotation == expected


@pytest.mark.parametrize("orientation", sorted(EXIF_VIA_ROTATION))
def test_convenience_reaches_all_exif_orientations(orientation: int) -> None:
    # set_display_rotation(degrees, hflip, vflip) must reproduce the exact same
    # matrix as the explicit EXIF table for every one of the 8 orientations.
    degrees, hflip, vflip = EXIF_VIA_ROTATION[orientation]
    expected = matrix_to_ints(EXIF_MATRICES[orientation])

    buf = io.BytesIO()
    container = av.open(buf, "w", format="mp4")
    stream = container.add_stream("mpeg4", rate=24)
    stream.width = WIDTH
    stream.height = HEIGHT
    stream.pix_fmt = "yuv420p"
    stream.set_display_rotation(degrees, hflip=hflip, vflip=vflip)
    for i in range(DURATION):
        frame = av.VideoFrame.from_ndarray(
            np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8), format="rgb24"
        )
        for packet in stream.encode(frame):
            container.mux(packet)
    for packet in stream.encode():
        container.mux(packet)
    container.close()

    buf.seek(0)
    got = _read_matrix(_read_frame(buf))
    if expected == matrix_to_ints(np.eye(3)):
        assert got is None  # identity emits no side data
    else:
        assert got == expected, f"exif {orientation}: wrote {expected}, read {got}"


def test_matrix_and_rotation_setters_are_mutually_exclusive() -> None:
    # Setting one path must clear the other so they don't both apply.
    buf = io.BytesIO()
    with av.open(buf, "w", format="mp4") as container:
        stream = container.add_stream("mpeg4", rate=24)
        stream.width = WIDTH
        stream.height = HEIGHT
        stream.pix_fmt = "yuv420p"
        stream.set_display_rotation(90)
        stream.set_display_matrix(None)  # clears both paths
        frame = av.VideoFrame.from_ndarray(
            np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8), format="rgb24"
        )
        for packet in stream.encode(frame):
            container.mux(packet)
        for packet in stream.encode():
            container.mux(packet)

    buf.seek(0)
    assert _read_matrix(_read_frame(buf)) is None


def test_set_display_matrix_validates_length() -> None:
    buf = io.BytesIO()
    with av.open(buf, "w", format="mp4") as container:
        stream = container.add_stream("mpeg4", rate=24)
        with pytest.raises(ValueError):
            stream.set_display_matrix([0, 1, 2])


def test_set_display_matrix_none_clears() -> None:
    buf = io.BytesIO()
    with av.open(buf, "w", format="mp4") as container:
        stream = container.add_stream("mpeg4", rate=24)
        stream.set_display_matrix(matrix_to_ints(EXIF_MATRICES[6]))
        stream.set_display_matrix(None)  # clear before encoding
        stream.width = WIDTH
        stream.height = HEIGHT
        stream.pix_fmt = "yuv420p"
        frame = av.VideoFrame.from_ndarray(
            np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8), format="rgb24"
        )
        for packet in stream.encode(frame):
            container.mux(packet)
        for packet in stream.encode():
            container.mux(packet)

    buf.seek(0)
    assert _read_matrix(_read_frame(buf)) is None
