import io

import av
import av.datasets

from .common import fate_suite


def test_video_remux() -> None:
    input_path = av.datasets.curated("pexels/time-lapse-video-of-night-sky-857195.mp4")
    input_ = av.open(input_path)
    output = av.open("remuxed.mkv", "w")

    in_stream = input_.streams.video[0]
    out_stream = output.add_stream_from_template(in_stream)

    for packet in input_.demux(in_stream):
        if packet.dts is None:
            continue

        packet.stream = out_stream
        output.mux(packet)

    input_.close()
    output.close()

    with av.open("remuxed.mkv") as container:
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
                if packet.dts is None:
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
