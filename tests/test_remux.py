import io

import numpy as np
import pytest

import av
import av.datasets

from .common import fate_suite, sandboxed


def test_video_remux() -> None:
    input_path = av.datasets.curated("pexels/time-lapse-video-of-night-sky-857195.mp4")
    output_path = sandboxed("remuxed.mkv")
    input_ = av.open(input_path)
    output = av.open(output_path, "w")

    in_stream = input_.streams.video[0]
    out_stream = output.add_stream_from_template(in_stream)

    for packet in input_.demux(in_stream):
        if packet.size == 0:  # skip the flushing packet, not keyframes with no DTS
            continue

        packet.stream = out_stream
        output.mux(packet)

    input_.close()
    output.close()

    with av.open(output_path) as container:
        # Assert output is a valid media file
        assert len(container.streams.video) == 1
        assert len(container.streams.audio) == 0
        assert container.streams.video[0].codec.name == "h264"

        packet_count = 0
        for packet in container.demux(video=0):
            packet_count += 1

        assert packet_count > 50


def test_add_mux_stream_video() -> None:
    """add_mux_stream creates a video stream without a CodecContext."""
    input_path = av.datasets.curated("pexels/time-lapse-video-of-night-sky-857195.mp4")

    buf = io.BytesIO()
    with av.open(input_path) as input_:
        in_stream = input_.streams.video[0]
        width = in_stream.codec_context.width
        height = in_stream.codec_context.height

        with av.open(buf, "w", format="mp4") as output:
            out_stream = output.add_mux_stream(
                in_stream.codec_context.name, width=width, height=height
            )
            assert out_stream.codec_context is None
            assert out_stream.type == "video"

            out_stream.time_base = in_stream.time_base

            for packet in input_.demux(in_stream):
                if packet.size == 0:
                    continue
                packet.stream = out_stream
                output.mux(packet)

    buf.seek(0)
    with av.open(buf) as result:
        assert len(result.streams.video) == 1
        assert result.streams.video[0].codec_context.width == width
        assert result.streams.video[0].codec_context.height == height


def test_add_mux_stream_no_codec_context() -> None:
    """add_mux_stream streams have no codec context and repr does not crash."""
    buf = io.BytesIO()
    with av.open(buf, "w", format="mp4") as output:
        video_stream = output.add_mux_stream("h264", width=1920, height=1080)
        audio_stream = output.add_mux_stream("aac", rate=44100)

        assert video_stream.codec_context is None
        assert audio_stream.codec_context is None
        # repr should not crash
        assert "video/<nocodec>" in repr(video_stream)
        assert "audio/<nocodec>" in repr(audio_stream)


def test_add_stream_from_template_copies_time_base() -> None:
    """add_stream_from_template must propagate the source stream's time_base.

    AVCodecParameters does not carry time_base, so without an explicit copy
    the output stream's time_base stays as None
    """
    video_path = av.datasets.curated("pexels/time-lapse-video-of-night-sky-857195.mp4")
    with (
        av.open(video_path) as input_,
        av.open(io.BytesIO(), "w", format="mp4") as output,
    ):
        in_video = input_.streams.video[0]
        out_video = output.add_stream_from_template(in_video)
        assert out_video.time_base is not None
        assert out_video.time_base == in_video.time_base

    audio_path = fate_suite("audio-reference/chorusnoise_2ch_44kHz_s16.wav")
    with (
        av.open(audio_path) as input_,
        av.open(io.BytesIO(), "w", format="wav") as output,
    ):
        in_audio = input_.streams.audio[0]
        out_audio = output.add_stream_from_template(in_audio)
        assert out_audio.time_base is not None
        assert out_audio.time_base == in_audio.time_base


def _make_b_frame_mkv(n: int = 48) -> io.BytesIO:
    """Encode `n` frames with B-frames into an in-memory MKV.

    Matroska stores only presentation timestamps, so when this is demuxed again
    libavformat cannot reconstruct a DTS for the leading reordered packets and
    leaves it as None -- including on the very first packet, which is the
    keyframe. That is exactly the layout that broke the remux example in #1917.
    """
    buf = io.BytesIO()
    with av.open(buf, "w", format="matroska") as out:
        stream = out.add_stream("h264", rate=30)
        stream.width, stream.height, stream.pix_fmt = 160, 120, "yuv420p"
        stream.options = {"bf": "3", "g": "30"}
        for i in range(n):
            img = np.full((120, 160, 3), (i * 5) % 256, dtype="uint8")
            frame = av.VideoFrame.from_ndarray(img, format="rgb24")
            for packet in stream.encode(frame):
                out.mux(packet)
        for packet in stream.encode(None):
            out.mux(packet)
    buf.seek(0)
    return buf


def _decoded_frame_count(buf: io.BytesIO) -> int:
    buf.seek(0)
    with av.open(buf, "r") as container:
        return sum(1 for _ in container.decode(video=0))


def test_remux_keeps_keyframe_with_none_dts() -> None:
    """Regression test for #1917.

    A keyframe can legitimately demux with ``dts is None`` (B-frame stream in a
    PTS-only container like MKV). The remux loop must skip only the empty
    flushing packet (``size == 0``), not every ``dts is None`` packet, otherwise
    the keyframe is dropped and the output is undecodable.
    """
    if av.codec.Codec("h264", "w").name != "libx264":
        pytest.skip("requires libx264")

    source = _make_b_frame_mkv()
    expected_frames = _decoded_frame_count(source)
    assert expected_frames > 0

    # Precondition: the first packet really is a keyframe without a DTS, which is
    # what the old `dts is None` filter would have wrongly discarded.
    source.seek(0)
    with av.open(source, "r") as input_:
        first = next(p for p in input_.demux(input_.streams.video[0]) if p.size)
        assert first.is_keyframe
        assert first.dts is None

    source.seek(0)
    output = io.BytesIO()
    with (
        av.open(source, "r") as input_,
        av.open(output, "w", format="matroska") as out,
    ):
        in_video = input_.streams.video[0]
        out_video = out.add_stream_from_template(in_video)
        for packet in input_.demux(in_video):
            if packet.size == 0:  # the flushing packet, not a keyframe with no DTS
                continue
            packet.stream = out_video
            out.mux(packet)

    # The keyframe survived: every frame still decodes and the first packet of
    # the remuxed stream is a keyframe.
    assert _decoded_frame_count(output) == expected_frames
    output.seek(0)
    with av.open(output, "r") as container:
        first_out = next(p for p in container.demux(video=0) if p.size)
        assert first_out.is_keyframe
