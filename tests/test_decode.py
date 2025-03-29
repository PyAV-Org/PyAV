import functools
import os
import pathlib
from fractions import Fraction

import numpy as np
import pytest

import av

from .common import TestCase, fate_suite


@functools.cache
def make_h264_test_video(path: str) -> None:
    """Generates a black H264 test video with two streams for testing hardware decoding."""

    # We generate a file here that's designed to be as compatible as possible with hardware
    # encoders. Hardware encoders are sometimes very picky and the errors we get are often
    # opaque, so there is nothing much we (PyAV) can do. The user needs to figure that out
    # if they want to use hwaccel. We only want to test the PyAV plumbing here.
    # Our video is H264, 1280x720p (note that some decoders have a minimum resolution limit), 24fps,
    # 8-bit yuv420p.
    pathlib.Path(path).parent.mkdir(parents=True, exist_ok=True)
    output_container = av.open(path, "w")

    streams = []
    for _ in range(2):
        stream = output_container.add_stream("libx264", rate=24)
        assert isinstance(stream, av.VideoStream)
        stream.width = 1280
        stream.height = 720
        stream.pix_fmt = "yuv420p"
        streams.append(stream)

    for _ in range(24):
        frame = av.VideoFrame.from_ndarray(
            np.zeros((720, 1280, 3), dtype=np.uint8), format="rgb24"
        )
        for stream in streams:
            for packet in stream.encode(frame):
                output_container.mux(packet)

    for stream in streams:
        for packet in stream.encode():
            output_container.mux(packet)

    output_container.close()


class TestDecode(TestCase):
    def test_decoded_video_frame_count(self) -> None:
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        video_stream = next(s for s in container.streams if s.type == "video")

        assert video_stream is container.streams.video[0]

        frame_count = 0
        for frame in container.decode(video_stream):
            frame_count += 1

        assert frame_count == video_stream.frames

    def test_decode_audio_corrupt(self) -> None:
        # write an empty file
        path = self.sandboxed("empty.flac")
        with open(path, "wb"):
            pass

        packet_count = 0
        frame_count = 0

        with av.open(path) as container:
            for packet in container.demux(audio=0):
                for frame in packet.decode():
                    frame_count += 1
                packet_count += 1

        assert packet_count == 1
        assert frame_count == 0

    def test_decode_audio_sample_count(self) -> None:
        container = av.open(fate_suite("audio-reference/chorusnoise_2ch_44kHz_s16.wav"))
        audio_stream = next(s for s in container.streams if s.type == "audio")

        assert audio_stream is container.streams.audio[0]
        assert isinstance(audio_stream, av.AudioStream)

        sample_count = 0

        for frame in container.decode(audio_stream):
            sample_count += frame.samples

        assert audio_stream.duration is not None
        assert audio_stream.time_base is not None
        total_samples = (
            audio_stream.duration
            * audio_stream.sample_rate.numerator
            / audio_stream.time_base.denominator
        )
        assert sample_count == total_samples

    def test_decoded_time_base(self) -> None:
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        stream = container.streams.video[0]

        assert stream.time_base == Fraction(1, 25)

        for packet in container.demux(stream):
            for frame in packet.decode():
                assert not isinstance(frame, av.subtitles.subtitle.SubtitleSet)
                assert packet.time_base == frame.time_base
                assert stream.time_base == frame.time_base
                return

    def test_decoded_motion_vectors(self) -> None:
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        stream = container.streams.video[0]
        codec_context = stream.codec_context
        codec_context.options = {"flags2": "+export_mvs"}

        for frame in container.decode(stream):
            vectors = frame.side_data.get("MOTION_VECTORS")
            if frame.key_frame:
                # Key frame don't have motion vectors
                assert vectors is None
            else:
                assert vectors is not None and len(vectors) > 0
                return

    def test_decoded_motion_vectors_no_flag(self) -> None:
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        stream = container.streams.video[0]

        for frame in container.decode(stream):
            vectors = frame.side_data.get("MOTION_VECTORS")
            if not frame.key_frame:
                assert vectors is None
                return

    def test_decode_video_corrupt(self) -> None:
        # write an empty file
        path = self.sandboxed("empty.h264")
        with open(path, "wb"):
            pass

        packet_count = 0
        frame_count = 0

        with av.open(path) as container:
            for packet in container.demux(video=0):
                for frame in packet.decode():
                    frame_count += 1
                packet_count += 1

        assert packet_count == 1
        assert frame_count == 0

    def test_decode_close_then_use(self) -> None:
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        container.close()

        # Check accessing every attribute either works or raises
        # an `AssertionError`.
        for attr in dir(container):
            with self.subTest(attr=attr):
                try:
                    getattr(container, attr)
                except AssertionError:
                    pass

    def test_flush_decoded_video_frame_count(self) -> None:
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        video_stream = container.streams.video[0]

        # Decode the first GOP, which requires a flush to get all frames
        have_keyframe = False
        input_count = 0
        output_count = 0

        for packet in container.demux(video_stream):
            if packet.is_keyframe:
                if have_keyframe:
                    break
                have_keyframe = True

            input_count += 1

            for frame in video_stream.decode(packet):
                output_count += 1

        # Check the test works as expected and requires a flush
        assert output_count < input_count

        for frame in video_stream.decode(None):
            # The Frame._time_base is not set by PyAV
            assert frame.time_base is None
            output_count += 1

        assert output_count == input_count

    def test_no_side_data(self) -> None:
        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        frame = next(container.decode(video=0))
        assert frame.rotation == 0

    def test_side_data(self) -> None:
        container = av.open(fate_suite("mov/displaymatrix.mov"))
        frame = next(container.decode(video=0))
        assert frame.rotation == -90

    def test_hardware_decode(self) -> None:
        hwdevices_available = av.codec.hwaccel.hwdevices_available()
        if "HWACCEL_DEVICE_TYPE" not in os.environ:
            pytest.skip(
                "Set the HWACCEL_DEVICE_TYPE to run this test. "
                f"Options are {' '.join(hwdevices_available)}"
            )

        HWACCEL_DEVICE_TYPE = os.environ["HWACCEL_DEVICE_TYPE"]
        assert HWACCEL_DEVICE_TYPE in hwdevices_available, (
            f"{HWACCEL_DEVICE_TYPE} not available"
        )

        test_video_path = "tests/assets/black.mp4"
        make_h264_test_video(test_video_path)

        hwaccel = av.codec.hwaccel.HWAccel(
            device_type=HWACCEL_DEVICE_TYPE, allow_software_fallback=False
        )

        container = av.open(test_video_path, hwaccel=hwaccel)
        video_stream = container.streams.video[0]
        assert video_stream.codec_context.is_hwaccel

        frame_count = 0
        for frame in container.decode(video_stream):
            frame_count += 1

        assert frame_count == video_stream.frames
