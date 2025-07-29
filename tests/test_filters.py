import errno
from fractions import Fraction

import numpy as np

import av
from av import AudioFrame, VideoFrame
from av.audio.frame import format_dtypes
from av.filter import Filter, Graph

from .common import TestCase, has_pillow


def generate_audio_frame(
    frame_num: int,
    input_format: str = "s16",
    layout: str = "stereo",
    sample_rate: int = 44100,
    frame_size: int = 1024,
) -> AudioFrame:
    """
    Generate audio frame representing part of the sinusoidal wave
    """
    frame = AudioFrame(format=input_format, layout=layout, samples=frame_size)
    frame.sample_rate = sample_rate
    frame.pts = frame_num * frame_size

    for i in range(frame.layout.nb_channels):
        data = np.zeros(frame_size, dtype=format_dtypes[input_format])
        for j in range(frame_size):
            data[j] = np.sin(2 * np.pi * (frame_num + j) * (i + 1) / float(frame_size))
        frame.planes[i].update(data)  # type: ignore

    return frame


def pull_until_blocked(graph: Graph) -> list[av.VideoFrame]:
    frames: list[av.VideoFrame] = []
    while True:
        try:
            frames.append(graph.vpull())
        except av.FFmpegError as e:
            if e.errno != errno.EAGAIN:
                raise
            return frames


class TestFilters(TestCase):
    def test_filter_descriptor(self) -> None:
        f = Filter("testsrc")
        assert f.name == "testsrc"
        assert f.description == "Generate test pattern."
        assert not f.dynamic_inputs
        assert len(f.inputs) == 0
        assert not f.dynamic_outputs
        assert len(f.outputs) == 1
        assert f.outputs[0].name == "default"
        assert f.outputs[0].type == "video"

    def test_dynamic_filter_descriptor(self):
        f = Filter("split")
        assert not f.dynamic_inputs
        assert len(f.inputs) == 1
        assert f.dynamic_outputs
        assert len(f.outputs) == 0

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
        assert src.outputs[0].link.output is lutrgb.inputs[0]
        assert lutrgb.inputs[0].link.input is src.outputs[0]

        frame = sink.pull()
        assert isinstance(frame, VideoFrame)

        if has_pillow:
            frame.to_image().save(self.sandboxed("mandelbrot2.png"))

    def test_auto_find_sink(self) -> None:
        graph = Graph()
        src = graph.add("testsrc")
        src.link_to(graph.add("buffersink"))
        graph.configure()

        frame = graph.vpull()

        if has_pillow:
            frame.to_image().save(self.sandboxed("mandelbrot3.png"))

    def test_delegate_sink(self) -> None:
        graph = Graph()
        src = graph.add("testsrc")
        src.link_to(graph.add("buffersink"))
        graph.configure()

        frame = src.pull()
        assert isinstance(frame, av.VideoFrame)

        if has_pillow:
            frame.to_image().save(self.sandboxed("mandelbrot4.png"))

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

    def test_audio_buffer_resample(self) -> None:
        graph = Graph()
        graph.link_nodes(
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
        ).configure()

        graph.push(
            generate_audio_frame(
                0, input_format="fltp", layout="stereo", sample_rate=48000
            )
        )
        out_frame = graph.pull()
        assert isinstance(out_frame, av.AudioFrame)
        assert out_frame.format.name == "s16"
        assert out_frame.layout.name == "stereo"
        assert out_frame.sample_rate == 44100

    def test_audio_buffer_frame_size(self):
        graph = Graph()
        graph.link_nodes(
            graph.add_abuffer(
                format="fltp",
                sample_rate=48000,
                layout="stereo",
                time_base=Fraction(1, 48000),
            ),
            graph.add("abuffersink"),
        ).configure()
        graph.set_audio_frame_size(256)
        graph.push(
            generate_audio_frame(
                0,
                input_format="fltp",
                layout="stereo",
                sample_rate=48000,
                frame_size=1024,
            )
        )
        out_frame = graph.pull()
        assert out_frame.sample_rate == 48000
        assert out_frame.samples == 256

    def test_audio_buffer_volume_filter(self):
        graph = Graph()
        graph.link_nodes(
            graph.add_abuffer(
                format="fltp",
                sample_rate=48000,
                layout="stereo",
                time_base=Fraction(1, 48000),
            ),
            graph.add("volume", volume="0.5"),
            graph.add("abuffersink"),
        ).configure()

        input_frame = generate_audio_frame(
            0, input_format="fltp", layout="stereo", sample_rate=48000
        )
        graph.push(input_frame)

        out_frame = graph.pull()
        assert out_frame.format.name == "fltp"
        assert out_frame.layout.name == "stereo"
        assert out_frame.sample_rate == 48000

        input_data = input_frame.to_ndarray()
        output_data = out_frame.to_ndarray()

        assert np.allclose(input_data * 0.5, output_data)

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
            assert frame.time_base == Fraction(1, 30)
            graph.vpush(frame)
            filtered_frames = pull_until_blocked(graph)

            if frame.pts == 0:
                # no output for the first input frame
                assert len(filtered_frames) == 0
            else:
                # we expect two filtered frames per input frame
                assert len(filtered_frames) == 2

                assert filtered_frames[0].pts == (frame.pts - 1) * 2
                assert filtered_frames[0].time_base == Fraction(1, 60)

                assert filtered_frames[1].pts == (frame.pts - 1) * 2 + 1
                assert filtered_frames[1].time_base == Fraction(1, 60)

    def test_EOF(self) -> None:
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
            graph.vpush(frame)

        graph.vpush(None)

        # if we do not push None, we get a BlockingIOError
        palette_frame = graph.vpull()

        assert isinstance(palette_frame, av.VideoFrame)
        assert palette_frame.width == 16
        assert palette_frame.height == 16
