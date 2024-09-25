import io
import math
from fractions import Fraction
from unittest import SkipTest

import numpy as np

import av
from av import AudioFrame, VideoFrame
from av.audio.stream import AudioStream
from av.video.stream import VideoStream

from .common import TestCase, fate_suite, has_pillow

WIDTH = 320
HEIGHT = 240
DURATION = 48


def write_rgb_rotate(output: av.container.OutputContainer) -> None:
    if not has_pillow:
        raise SkipTest("Don't have Pillow")

    import PIL.Image as Image

    output.metadata["title"] = "container"
    output.metadata["key"] = "value"

    stream = output.add_stream("mpeg4", 24)
    stream.width = WIDTH
    stream.height = HEIGHT
    stream.pix_fmt = "yuv420p"

    for frame_i in range(DURATION):
        frame = VideoFrame(WIDTH, HEIGHT, "rgb24")
        image = Image.new(
            "RGB",
            (WIDTH, HEIGHT),
            (
                int(255 * (0.5 + 0.5 * math.sin(frame_i / DURATION * 2 * math.pi))),
                int(
                    255
                    * (
                        0.5
                        + 0.5
                        * math.sin(frame_i / DURATION * 2 * math.pi + 2 / 3 * math.pi)
                    )
                ),
                int(
                    255
                    * (
                        0.5
                        + 0.5
                        * math.sin(frame_i / DURATION * 2 * math.pi + 4 / 3 * math.pi)
                    )
                ),
            ),
        )
        frame.planes[0].update(image.tobytes())

        for packet in stream.encode_lazy(frame):
            output.mux(packet)

    for packet in stream.encode_lazy(None):
        output.mux(packet)


def assert_rgb_rotate(
    self, input_: av.container.InputContainer, is_dash: bool = False
) -> None:
    # Now inspect it a little.
    assert len(input_.streams) == 1
    assert input_.metadata.get("Title" if is_dash else "title") == "container"
    assert input_.metadata.get("key") is None

    stream = input_.streams[0]

    if is_dash:
        # The DASH format doesn't provide a duration for the stream
        # and so the container duration (micro seconds) is checked instead
        assert input_.duration == 2000000
        expected_average_rate = 24
        expected_duration = None
        expected_frames = 0
        expected_id = 0
    else:
        expected_average_rate = 24
        expected_duration = 24576
        expected_frames = 48
        expected_id = 1

    # actual stream properties
    assert isinstance(stream, VideoStream)
    assert stream.average_rate == expected_average_rate
    assert stream.base_rate == 24
    assert stream.duration == expected_duration
    assert stream.guessed_rate == 24
    assert stream.frames == expected_frames
    assert stream.id == expected_id
    assert stream.index == 0
    assert stream.profile == "Simple Profile"
    assert stream.start_time == 0
    assert stream.time_base == Fraction(1, 12288)
    assert stream.type == "video"

    # codec context properties
    assert stream.codec.name == "mpeg4"
    assert stream.codec.long_name == "MPEG-4 part 2"
    assert stream.format.name == "yuv420p"
    assert stream.format.width == WIDTH
    assert stream.format.height == HEIGHT


class TestBasicVideoEncoding(TestCase):
    def test_default_options(self) -> None:
        with av.open(self.sandboxed("output.mov"), "w") as output:
            stream = output.add_stream("mpeg4")
            assert stream in output.streams.video
            assert stream.average_rate == Fraction(24, 1)
            assert stream.time_base is None

            # codec context properties
            assert stream.bit_rate == 1024000
            assert stream.format.height == 480
            assert stream.format.name == "yuv420p"
            assert stream.format.width == 640
            assert stream.height == 480
            assert stream.pix_fmt == "yuv420p"
            assert stream.width == 640

    def test_encoding(self) -> None:
        path = self.sandboxed("rgb_rotate.mov")

        with av.open(path, "w") as output:
            write_rgb_rotate(output)
        with av.open(path) as input:
            assert_rgb_rotate(self, input)

    def test_encoding_with_pts(self) -> None:
        path = self.sandboxed("video_with_pts.mov")

        with av.open(path, "w") as output:
            stream = output.add_stream("h264", 24)
            assert stream in output.streams.video
            stream.width = WIDTH
            stream.height = HEIGHT
            stream.pix_fmt = "yuv420p"

            for i in range(DURATION):
                frame = VideoFrame(WIDTH, HEIGHT, "rgb24")
                frame.pts = i * 2000
                frame.time_base = Fraction(1, 48000)

                for packet in stream.encode(frame):
                    assert packet.time_base == Fraction(1, 24)
                    output.mux(packet)

            for packet in stream.encode(None):
                assert packet.time_base == Fraction(1, 24)
                output.mux(packet)

    def test_encoding_with_unicode_filename(self) -> None:
        path = self.sandboxed("¢∞§¶•ªº.mov")

        with av.open(path, "w") as output:
            write_rgb_rotate(output)
        with av.open(path) as input:
            assert_rgb_rotate(self, input)


class TestBasicAudioEncoding(TestCase):
    def test_default_options(self) -> None:
        with av.open(self.sandboxed("output.mov"), "w") as output:
            stream = output.add_stream("mp2")
            assert stream in output.streams.audio
            assert stream.time_base is None

            # codec context properties
            assert stream.bit_rate == 128000
            assert stream.format.name == "s16"
            assert stream.sample_rate == 48000

    def test_transcode(self) -> None:
        path = self.sandboxed("audio_transcode.mov")

        with av.open(path, "w") as output:
            output.metadata["title"] = "container"
            output.metadata["key"] = "value"

            sample_rate = 48000
            channel_layout = "stereo"
            sample_fmt = "s16"

            stream = output.add_stream("mp2", sample_rate)
            assert stream in output.streams.audio

            ctx = stream.codec_context
            ctx.sample_rate = sample_rate
            stream.format = sample_fmt
            ctx.layout = channel_layout

            with av.open(
                fate_suite("audio-reference/chorusnoise_2ch_44kHz_s16.wav")
            ) as src:
                for frame in src.decode(audio=0):
                    for packet in stream.encode(frame):
                        output.mux(packet)

            for packet in stream.encode(None):
                output.mux(packet)

        with av.open(path) as container:
            assert len(container.streams) == 1
            assert container.metadata.get("title") == "container"
            assert container.metadata.get("key") is None

            assert isinstance(container.streams[0], AudioStream)
            stream = container.streams[0]

            # codec context properties
            assert stream.format.name == "s16p"
            assert stream.sample_rate == sample_rate


class TestEncodeStreamSemantics(TestCase):
    def test_stream_index(self) -> None:
        with av.open(self.sandboxed("output.mov"), "w") as output:
            vstream = output.add_stream("mpeg4", 24)
            assert vstream in output.streams.video
            vstream.pix_fmt = "yuv420p"
            vstream.width = 320
            vstream.height = 240

            astream = output.add_stream("mp2", 48000)
            assert astream in output.streams.audio
            astream.layout = "stereo"  # type: ignore
            astream.format = "s16"  # type: ignore

            assert vstream.index == 0
            assert astream.index == 1

            vframe = VideoFrame(320, 240, "yuv420p")
            vpacket = vstream.encode(vframe)[0]

            assert vpacket.stream is vstream
            assert vpacket.stream_index == 0

            for i in range(10):
                if astream.frame_size != 0:
                    frame_size = astream.frame_size
                else:
                    # decoder didn't indicate constant frame size
                    frame_size = 1000
                aframe = AudioFrame("s16", "stereo", samples=frame_size)
                aframe.sample_rate = 48000
                apackets = astream.encode(aframe)
                if apackets:
                    apacket = apackets[0]
                    break

            assert apacket.stream is astream
            assert apacket.stream_index == 1

    def test_stream_audio_resample(self) -> None:
        with av.open(self.sandboxed("output.mov"), "w") as output:
            vstream = output.add_stream("mpeg4", 24)
            vstream.pix_fmt = "yuv420p"
            vstream.width = 320
            vstream.height = 240

            astream = output.add_stream("aac", sample_rate=8000, layout="mono")
            frame_size = 512

            pts_expected = [-1024, 0, 512, 1024, 1536, 2048, 2560]
            pts = 0
            for i in range(15):
                aframe = AudioFrame("s16", "mono", samples=frame_size)
                aframe.sample_rate = 8000
                aframe.time_base = Fraction(1, 1000)
                aframe.pts = pts
                aframe.dts = pts
                pts += 32
                apackets = astream.encode(aframe)
                if apackets:
                    apacket = apackets[0]
                    assert apacket.pts == pts_expected.pop(0)
                    assert apacket.time_base == Fraction(1, 8000)

            apackets = astream.encode(None)
            if apackets:
                apacket = apackets[0]
                assert apacket.pts == pts_expected.pop(0)
                assert apacket.time_base == Fraction(1, 8000)

    def test_set_id_and_time_base(self) -> None:
        with av.open(self.sandboxed("output.mov"), "w") as output:
            stream = output.add_stream("mp2")
            assert stream in output.streams.audio

            # set id
            assert stream.id == 0
            stream.id = 1
            assert stream.id == 1

            # set time_base
            assert stream.time_base is None
            stream.time_base = Fraction(1, 48000)
            assert stream.time_base == Fraction(1, 48000)


def encode_file_with_max_b_frames(max_b_frames: int) -> io.BytesIO:
    """
    Create an encoded video file (or file-like object) with the given
    maximum run of B frames.

    max_b_frames: non-negative integer which is the maximum allowed run
        of consecutive B frames.

    Returns: a file-like object.
    """
    # Create a video file that is entirely arbitrary, but with the passed
    # max_b_frames parameter.
    file = io.BytesIO()
    container = av.open(file, mode="w", format="mp4")
    stream = container.add_stream("h264", rate=30)
    stream.width = 640
    stream.height = 480
    stream.pix_fmt = "yuv420p"
    stream.codec_context.gop_size = 15
    stream.codec_context.max_b_frames = max_b_frames

    for i in range(50):
        array = np.empty((stream.height, stream.width, 3), dtype=np.uint8)
        # This appears to hit a complexity "sweet spot" that makes the codec
        # want to use B frames.
        array[:, :] = (i, 0, 255 - i)
        frame = av.VideoFrame.from_ndarray(array, format="rgb24")
        for packet in stream.encode(frame):
            container.mux(packet)

    for packet in stream.encode():
        container.mux(packet)

    container.close()
    file.seek(0)

    return file


def max_b_frame_run_in_file(file: io.BytesIO) -> int:
    """
    Count the maximum run of B frames in a file (or file-like object).

    file: the file or file-like object in which to count the maximum run
        of B frames. The file should contain just one video stream.

    Returns: non-negative integer which is the maximum B frame run length.
    """
    container = av.open(file, "r")
    stream = container.streams.video[0]

    max_b_frame_run = 0
    b_frame_run = 0
    for frame in container.decode(stream):
        if frame.pict_type == av.video.frame.PictureType.B:
            b_frame_run += 1
        else:
            max_b_frame_run = max(max_b_frame_run, b_frame_run)
            b_frame_run = 0

    # Outside chance that the longest run was at the end of the file.
    max_b_frame_run = max(max_b_frame_run, b_frame_run)

    container.close()

    return max_b_frame_run


class TestMaxBFrameEncoding(TestCase):
    def test_max_b_frames(self) -> None:
        """
        Test that we never get longer runs of B frames than we asked for with
        the max_b_frames property.
        """
        for max_b_frames in range(4):
            file = encode_file_with_max_b_frames(max_b_frames)
            actual_max_b_frames = max_b_frame_run_in_file(file)
            self.assertTrue(actual_max_b_frames <= max_b_frames)
