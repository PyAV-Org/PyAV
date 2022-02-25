from __future__ import division

from fractions import Fraction
from unittest import SkipTest
import math

from av import AudioFrame, VideoFrame
from av.audio.stream import AudioStream
from av.video.stream import VideoStream
import av

from .common import Image, TestCase, fate_suite


WIDTH = 320
HEIGHT = 240
DURATION = 48


def write_rgb_rotate(output):

    if not Image:
        raise SkipTest()

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

        for packet in stream.encode(frame):
            output.mux(packet)

    for packet in stream.encode(None):
        output.mux(packet)

    # Done!
    output.close()


def assert_rgb_rotate(self, input_):

    # Now inspect it a little.
    self.assertEqual(len(input_.streams), 1)
    self.assertEqual(input_.metadata.get("title"), "container", input_.metadata)
    self.assertEqual(input_.metadata.get("key"), None)
    stream = input_.streams[0]
    self.assertIsInstance(stream, VideoStream)
    self.assertEqual(stream.type, "video")
    self.assertEqual(stream.name, "mpeg4")
    self.assertEqual(
        stream.average_rate, 24
    )  # Only because we constructed is precisely.
    self.assertEqual(stream.rate, Fraction(24, 1))
    self.assertEqual(stream.time_base * stream.duration, 2)
    self.assertEqual(stream.format.name, "yuv420p")
    self.assertEqual(stream.format.width, WIDTH)
    self.assertEqual(stream.format.height, HEIGHT)


class TestBasicVideoEncoding(TestCase):
    def test_rgb_rotate(self):

        path = self.sandboxed("rgb_rotate.mov")
        output = av.open(path, "w")

        write_rgb_rotate(output)
        assert_rgb_rotate(self, av.open(path))

    def test_encoding_with_pts(self):

        path = self.sandboxed("video_with_pts.mov")
        output = av.open(path, "w")

        stream = output.add_stream("libx264", 24)
        stream.width = WIDTH
        stream.height = HEIGHT
        stream.pix_fmt = "yuv420p"

        for i in range(DURATION):
            frame = VideoFrame(WIDTH, HEIGHT, "rgb24")
            frame.pts = i * 2000
            frame.time_base = Fraction(1, 48000)

            for packet in stream.encode(frame):
                self.assertEqual(packet.time_base, Fraction(1, 24))
                output.mux(packet)

        for packet in stream.encode(None):
            self.assertEqual(packet.time_base, Fraction(1, 24))
            output.mux(packet)

        output.close()


class TestBasicAudioEncoding(TestCase):
    def test_audio_transcode(self):

        path = self.sandboxed("audio_transcode.mov")
        output = av.open(path, "w")
        output.metadata["title"] = "container"
        output.metadata["key"] = "value"

        sample_rate = 48000
        channel_layout = "stereo"
        channels = 2
        sample_fmt = "s16"

        stream = output.add_stream("mp2", sample_rate)

        ctx = stream.codec_context
        ctx.time_base = sample_rate
        ctx.sample_rate = sample_rate
        ctx.format = sample_fmt
        ctx.layout = channel_layout
        ctx.channels = channels

        src = av.open(fate_suite("audio-reference/chorusnoise_2ch_44kHz_s16.wav"))
        for frame in src.decode(audio=0):
            frame.pts = None
            for packet in stream.encode(frame):
                output.mux(packet)

        for packet in stream.encode(None):
            output.mux(packet)

        output.close()

        container = av.open(path)
        self.assertEqual(len(container.streams), 1)
        self.assertEqual(
            container.metadata.get("title"), "container", container.metadata
        )
        self.assertEqual(container.metadata.get("key"), None)

        stream = container.streams[0]
        self.assertIsInstance(stream, AudioStream)
        self.assertEqual(stream.codec_context.sample_rate, sample_rate)
        self.assertEqual(stream.codec_context.format.name, "s16p")
        self.assertEqual(stream.codec_context.channels, channels)


class TestEncodeStreamSemantics(TestCase):
    def test_audio_default_options(self):
        output = av.open(self.sandboxed("output.mov"), "w")

        stream = output.add_stream("mp2")
        self.assertEqual(stream.bit_rate, 128000)
        self.assertEqual(stream.format.name, "s16")
        self.assertEqual(stream.rate, 48000)
        self.assertEqual(stream.ticks_per_frame, 1)
        self.assertEqual(stream.time_base, None)

    def test_video_default_options(self):
        output = av.open(self.sandboxed("output.mov"), "w")

        stream = output.add_stream("mpeg4")
        self.assertEqual(stream.bit_rate, 1024000)
        self.assertEqual(stream.format.height, 480)
        self.assertEqual(stream.format.name, "yuv420p")
        self.assertEqual(stream.format.width, 640)
        self.assertEqual(stream.height, 480)
        self.assertEqual(stream.pix_fmt, "yuv420p")
        self.assertEqual(stream.rate, Fraction(24, 1))
        self.assertEqual(stream.ticks_per_frame, 1)
        self.assertEqual(stream.time_base, None)
        self.assertEqual(stream.width, 640)

    def test_stream_index(self):
        output = av.open(self.sandboxed("output.mov"), "w")

        vstream = output.add_stream("mpeg4", 24)
        vstream.pix_fmt = "yuv420p"
        vstream.width = 320
        vstream.height = 240

        astream = output.add_stream("mp2", 48000)
        astream.channels = 2
        astream.format = "s16"

        self.assertEqual(vstream.index, 0)
        self.assertEqual(astream.index, 1)

        vframe = VideoFrame(320, 240, "yuv420p")
        vpacket = vstream.encode(vframe)[0]

        self.assertIs(vpacket.stream, vstream)
        self.assertEqual(vpacket.stream_index, 0)

        for i in range(10):
            if astream.frame_size != 0:
                frame_size = astream.frame_size
            else:
                # decoder didn't indicate constant frame size
                frame_size = 1000
            aframe = AudioFrame("s16", "stereo", samples=frame_size)
            aframe.rate = 48000
            apackets = astream.encode(aframe)
            if apackets:
                apacket = apackets[0]
                break

        self.assertIs(apacket.stream, astream)
        self.assertEqual(apacket.stream_index, 1)

    def test_audio_set_time_base_and_id(self):
        output = av.open(self.sandboxed("output.mov"), "w")

        stream = output.add_stream("mp2")
        self.assertEqual(stream.rate, 48000)
        self.assertEqual(stream.time_base, None)
        stream.time_base = Fraction(1, 48000)
        self.assertEqual(stream.time_base, Fraction(1, 48000))
        self.assertEqual(stream.id, 0)
        stream.id = 1
        self.assertEqual(stream.id, 1)
