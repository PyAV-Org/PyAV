import errno
from fractions import Fraction
from unittest import SkipTest

import numpy as np

import av
from av import AudioFrame, VideoFrame
from av.audio.frame import format_dtypes
from av.filter import Filter, Graph

from .common import Image, TestCase, fate_suite


def generate_audio_frame(
    frame_num, input_format="s16", layout="stereo", sample_rate=44100, frame_size=1024
):
    """
    Generate audio frame representing part of the sinusoidal wave
    :param input_format: default: s16
    :param layout: default: stereo
    :param sample_rate: default: 44100
    :param frame_size: default: 1024
    :param frame_num: frame number
    :return: audio frame for sinusoidal wave audio signal slice
    """
    frame = AudioFrame(format=input_format, layout=layout, samples=frame_size)
    frame.sample_rate = sample_rate
    frame.pts = frame_num * frame_size

    for i in range(len(frame.layout.channels)):
        data = np.zeros(frame_size, dtype=format_dtypes[input_format])
        for j in range(frame_size):
            data[j] = np.sin(2 * np.pi * (frame_num + j) * (i + 1) / float(frame_size))
        frame.planes[i].update(data)

    return frame


def pull_until_blocked(graph):
    frames = []
    while True:
        try:
            frames.append(graph.pull())
        except av.AVError as e:
            if e.errno != errno.EAGAIN:
                raise
            return frames


class TestFilters(TestCase):
    def test_filter_descriptor(self):
        f = Filter("testsrc")
        self.assertEqual(f.name, "testsrc")
        self.assertEqual(f.description, "Generate test pattern.")
        self.assertFalse(f.dynamic_inputs)
        self.assertEqual(len(f.inputs), 0)
        self.assertFalse(f.dynamic_outputs)
        self.assertEqual(len(f.outputs), 1)
        self.assertEqual(f.outputs[0].name, "default")
        self.assertEqual(f.outputs[0].type, "video")

    def test_dynamic_filter_descriptor(self):
        f = Filter("split")
        self.assertFalse(f.dynamic_inputs)
        self.assertEqual(len(f.inputs), 1)
        self.assertTrue(f.dynamic_outputs)
        self.assertEqual(len(f.outputs), 0)

    def test_generator_graph(self):
        graph = Graph()
        src = graph.add("testsrc")
        lutrgb = graph.add(
            "lutrgb",
            "r=maxval+minval-val:g=maxval+minval-val:b=maxval+minval-val",
            name="invert",
        )
        sink = graph.add("buffersink")
        src.link_to(lutrgb)
        lutrgb.link_to(sink)

        # pads and links
        self.assertIs(src.outputs[0].link.output, lutrgb.inputs[0])
        self.assertIs(lutrgb.inputs[0].link.input, src.outputs[0])

        frame = sink.pull()
        self.assertIsInstance(frame, VideoFrame)

        if Image:
            frame.to_image().save(self.sandboxed("mandelbrot2.png"))

    def test_auto_find_sink(self):
        graph = Graph()
        src = graph.add("testsrc")
        src.link_to(graph.add("buffersink"))
        graph.configure()

        frame = graph.pull()

        if Image:
            frame.to_image().save(self.sandboxed("mandelbrot3.png"))

    def test_delegate_sink(self):
        graph = Graph()
        src = graph.add("testsrc")
        src.link_to(graph.add("buffersink"))
        graph.configure()

        frame = src.pull()

        if Image:
            frame.to_image().save(self.sandboxed("mandelbrot4.png"))

    def test_haldclut_graph(self):
        raise SkipTest()

        graph = Graph()

        img = Image.open(fate_suite("png1/lena-rgb24.png"))
        frame = VideoFrame.from_image(img)
        img_source = graph.add_buffer(frame)

        hald_img = Image.open("hald_7.png")
        hald_frame = VideoFrame.from_image(hald_img)
        hald_source = graph.add_buffer(hald_frame)

        hald_filter = graph.add("haldclut")

        sink = graph.add("buffersink")

        img_source.link(0, hald_filter, 0)
        hald_source.link(0, hald_filter, 1)
        hald_filter.link(0, sink, 0)
        graph.config()

        self.assertIs(img_source.outputs[0].linked_to, hald_filter.inputs[0])
        self.assertIs(hald_source.outputs[0].linked_to, hald_filter.inputs[1])
        self.assertIs(hald_filter.outputs[0].linked_to, sink.inputs[0])

        hald_source.push(hald_frame)

        img_source.push(frame)

        frame = sink.pull()
        self.assertIsInstance(frame, VideoFrame)
        frame.to_image().save(self.sandboxed("filtered.png"))

    def test_audio_buffer_sink(self):
        graph = Graph()
        audio_buffer = graph.add_abuffer(
            format="fltp",
            sample_rate=48000,
            layout="stereo",
            time_base=Fraction(1, 48000),
        )
        audio_buffer.link_to(graph.add("abuffersink"))
        graph.configure()

        try:
            graph.pull()
        except OSError as e:
            # we haven't pushed any input so expect no frames / EAGAIN
            if e.errno != errno.EAGAIN:
                raise

    @staticmethod
    def link_nodes(*nodes):
        for c, n in zip(nodes, nodes[1:]):
            c.link_to(n)

    def test_audio_buffer_resample(self):
        graph = Graph()
        self.link_nodes(
            graph.add_abuffer(
                format="fltp",
                sample_rate=48000,
                layout="stereo",
                time_base=Fraction(1, 48000),
            ),
            graph.add(
                "aformat", "sample_fmts=s16:sample_rates=44100:channel_layouts=stereo"
            ),
            graph.add("abuffersink"),
        )
        graph.configure()

        graph.push(
            generate_audio_frame(
                0, input_format="fltp", layout="stereo", sample_rate=48000
            )
        )
        out_frame = graph.pull()
        self.assertEqual(out_frame.format.name, "s16")
        self.assertEqual(out_frame.layout.name, "stereo")
        self.assertEqual(out_frame.sample_rate, 44100)

    def test_audio_buffer_volume_filter(self):
        graph = Graph()
        self.link_nodes(
            graph.add_abuffer(
                format="fltp",
                sample_rate=48000,
                layout="stereo",
                time_base=Fraction(1, 48000),
            ),
            graph.add("volume", volume="0.5"),
            graph.add("abuffersink"),
        )
        graph.configure()

        input_frame = generate_audio_frame(
            0, input_format="fltp", layout="stereo", sample_rate=48000
        )
        graph.push(input_frame)

        out_frame = graph.pull()
        self.assertEqual(out_frame.format.name, "fltp")
        self.assertEqual(out_frame.layout.name, "stereo")
        self.assertEqual(out_frame.sample_rate, 48000)

        input_data = input_frame.to_ndarray()
        output_data = out_frame.to_ndarray()

        self.assertTrue(
            np.allclose(input_data * 0.5, output_data), "Check that volume is reduced"
        )

    def test_video_buffer(self):
        input_container = av.open(format="lavfi", file="color=c=pink:duration=1:r=30")
        input_video_stream = input_container.streams.video[0]

        graph = av.filter.Graph()
        buffer = graph.add_buffer(template=input_video_stream)
        bwdif = graph.add("bwdif", "send_field:tff:all")
        buffersink = graph.add("buffersink")
        buffer.link_to(bwdif)
        bwdif.link_to(buffersink)
        graph.configure()

        for frame in input_container.decode():
            self.assertEqual(frame.time_base, Fraction(1, 30))
            graph.push(frame)
            filtered_frames = pull_until_blocked(graph)

            if frame.pts == 0:
                # no output for the first input frame
                self.assertEqual(len(filtered_frames), 0)
            else:
                # we expect two filtered frames per input frame
                self.assertEqual(len(filtered_frames), 2)

                self.assertEqual(filtered_frames[0].pts, (frame.pts - 1) * 2)
                self.assertEqual(filtered_frames[0].time_base, Fraction(1, 60))

                self.assertEqual(filtered_frames[1].pts, (frame.pts - 1) * 2 + 1)
                self.assertEqual(filtered_frames[1].time_base, Fraction(1, 60))

    def test_EOF(self):
        input_container = av.open(format="lavfi", file="color=c=pink:duration=1:r=30")
        video_stream = input_container.streams.video[0]

        graph = av.filter.Graph()
        video_in = graph.add_buffer(template=video_stream)
        palette_gen_filter = graph.add("palettegen")
        video_out = graph.add("buffersink")
        video_in.link_to(palette_gen_filter)
        palette_gen_filter.link_to(video_out)
        graph.configure()

        for frame in input_container.decode(video=0):
            graph.push(frame)

        graph.push(None)

        # if we do not push None, we get a BlockingIOError
        palette_frame = graph.pull()

        self.assertIsInstance(palette_frame, av.VideoFrame)
        self.assertEqual(palette_frame.width, 16)
        self.assertEqual(palette_frame.height, 16)
