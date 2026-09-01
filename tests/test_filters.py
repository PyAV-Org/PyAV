import errno
from fractions import Fraction

import numpy as np
import pytest

import av
from av import AudioFrame, AVRational, VideoFrame
from av.audio.frame import format_dtypes
from av.filter import Filter, Graph
from av.filter.context import FilterContext

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

    def test_graph_rejects_invalid_hw_device(self) -> None:
        with pytest.raises(TypeError, match="hw_device must be an HWDevice"):
            Graph(hw_device=object())  # type: ignore[arg-type]

    def test_hw_device_rejects_unknown_type(self) -> None:
        with pytest.raises(ValueError, match="Unknown hardware device type"):
            av.codec.hwaccel.HWDevice("definitely-not-a-hardware-device")

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

    def test_link_keeps_graph_alive(self) -> None:
        import gc

        graph = Graph()
        src = graph.add("testsrc")
        sink = graph.add("buffersink")
        src.link_to(sink)
        graph.configure()

        link = src.outputs[0].link
        assert link is not None
        del graph, src, sink
        gc.collect()

        # The link points into the graph's memory, so holding it must hold the
        # graph, exactly as holding a filter context does.
        assert link.graph is not None
        assert link.input.context.name == "testsrc"
        assert link.output.context.name == "buffersink"

    def test_link_pads_follow_auto_inserted_filters(self) -> None:
        # Configuring a graph splices a converter in where formats disagree,
        # which re-points the link. Reading a pad early must not pin the answer.
        def build() -> tuple[Graph, FilterContext]:
            graph = Graph()
            src = graph.add_buffer(
                width=64, height=64, format="yuv420p", time_base=AVRational(1, 24)
            )
            lutrgb = graph.add("lutrgb", "r=maxval-val:g=maxval-val:b=maxval-val")
            sink = graph.add("buffersink")
            src.link_to(lutrgb)
            lutrgb.link_to(sink)
            return graph, src

        early_graph, early_src = build()
        early_link = early_src.outputs[0].link
        assert early_link is not None
        early_link.output  # would have been cached
        early_graph.configure()

        late_graph, late_src = build()
        late_graph.configure()
        late_link = late_src.outputs[0].link
        assert late_link is not None

        assert early_link.output.context.name == late_link.output.context.name
        assert early_link.input.context.name == late_link.input.context.name

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

    def test_audio_frame_metadata(self) -> None:
        graph = Graph()
        graph.link_nodes(
            graph.add_abuffer(
                format="fltp",
                sample_rate=48000,
                layout="stereo",
                time_base=Fraction(1, 48000),
            ),
            graph.add("ebur128", "metadata=1"),
            graph.add("abuffersink"),
        ).configure()

        frame = AudioFrame.from_ndarray(
            np.zeros((2, 4800), dtype=np.float32),
            format="fltp",
            layout="stereo",
        )
        frame.sample_rate = 48000
        frame.time_base = Fraction(1, 48000)
        frame.pts = 0

        graph.push(frame)
        graph.push(None)
        output = graph.pull()
        metadata = output.metadata

        assert "lavfi.r128.I" in metadata
        assert "lavfi.r128.LRA" in metadata

        # Frame.metadata returns a copy of the underlying AVDictionary.
        metadata.clear()
        assert "lavfi.r128.I" in output.metadata

    def _test_video_buffer(self, graph):
        input_container = av.open(format="lavfi", file="color=c=pink:duration=1:r=30")
        input_video_stream = input_container.streams.video[0]

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

    def test_video_buffer(self):
        self._test_video_buffer(av.filter.Graph())

    def test_video_buffer_threading(self):
        graph = av.filter.Graph()
        graph.threads = 4
        self._test_video_buffer(graph)

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

    def test_push_at_index(self) -> None:
        # overlay has two video buffer sources; `at` targets a single one,
        # instead of broadcasting the same frame to both (like auto-editor's
        # pushIdx/flushIdx).
        width, height = 16, 16

        base = VideoFrame(width, height, "yuv420p")
        for plane in base.planes:
            plane.update(bytes(plane.buffer_size))
        base.pts = 0
        base.time_base = Fraction(1, 30)

        top = VideoFrame(width, height, "yuv420p")
        for i, plane in enumerate(top.planes):
            plane.update(bytes([200 if i == 0 else 128]) * plane.buffer_size)
        top.pts = 0
        top.time_base = Fraction(1, 30)

        graph = Graph()
        b0 = graph.add_buffer(
            width=width, height=height, format=base.format, time_base=base.time_base
        )
        b1 = graph.add_buffer(
            width=width, height=height, format=top.format, time_base=top.time_base
        )
        overlay = graph.add("overlay", "x=0:y=0")
        sink = graph.add("buffersink")
        b0.link_to(overlay, 0, 0)
        b1.link_to(overlay, 0, 1)
        overlay.link_to(sink)
        graph.configure()

        graph.push(base, at=0)
        graph.push(top, at=1)
        graph.push(None, at=0)
        graph.push(None, at=1)

        out = graph.vpull()
        assert isinstance(out, av.VideoFrame)
        assert (out.width, out.height) == (width, height)

        with self.assertRaises(IndexError):
            graph.push(base, at=2)

    def test_graph_threads(self) -> None:
        graph = Graph()
        assert graph.threads == 0

        graph.threads = 4
        assert graph.threads == 4

        graph.add("testsrc")

        with self.assertRaises(RuntimeError):
            graph.threads = 2
