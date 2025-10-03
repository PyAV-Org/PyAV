import os
from fractions import Fraction

import pytest

import av
import av.datasets

from .common import fate_suite


class TestStreams:
    @pytest.fixture(autouse=True)
    def cleanup(self):
        yield
        for file in (
            "data.ts",
            "data_source.ts",
            "data_copy.ts",
            "out.mkv",
            "video_with_attachment.mkv",
            "remuxed_attachment.mkv",
        ):
            if os.path.exists(file):
                os.remove(file)

    def test_stream_tuples(self) -> None:
        for fate_name in ("h264/interlaced_crop.mp4",):
            container = av.open(fate_suite(fate_name))

            video_streams = tuple([s for s in container.streams if s.type == "video"])
            assert video_streams == container.streams.video

            audio_streams = tuple([s for s in container.streams if s.type == "audio"])
            assert audio_streams == container.streams.audio

    def test_loudnorm(self) -> None:
        container = av.open(
            fate_suite("amv/MTV_high_res_320x240_sample_Penguin_Joke_MTV_from_WMV.amv")
        )
        audio = container.streams.audio[0]
        stats = av.filter.loudnorm.stats("i=-24.0:lra=7.0:tp=-2.0", audio)

        assert isinstance(stats, bytes) and len(stats) > 30
        assert b"inf" not in stats
        assert b'"input_i"' in stats

    def test_selection(self) -> None:
        container = av.open(
            fate_suite("amv/MTV_high_res_320x240_sample_Penguin_Joke_MTV_from_WMV.amv")
        )
        video = container.streams.video[0]

        video.thread_type = av.codec.context.ThreadType.AUTO
        assert video.thread_type == av.codec.context.ThreadType.AUTO

        video.thread_type = 0x03
        assert video.thread_type == av.codec.context.ThreadType.AUTO

        video.thread_type = "AUTO"
        assert video.thread_type == av.codec.context.ThreadType.AUTO

        audio = container.streams.audio[0]

        assert [video] == container.streams.get(video=0)
        assert [video] == container.streams.get(video=(0,))

        assert video == container.streams.best("video")
        assert audio == container.streams.best("audio")

        container = av.open(fate_suite("sub/MovText_capability_tester.mp4"))
        subtitle = container.streams.subtitles[0]
        assert subtitle == container.streams.best("subtitle")

        container = av.open(fate_suite("mxf/track_01_v02.mxf"))
        data = container.streams.data[0]
        assert data == container.streams.best("data")

    def test_printing_video_stream(self) -> None:
        input_ = av.open(
            fate_suite("amv/MTV_high_res_320x240_sample_Penguin_Joke_MTV_from_WMV.amv")
        )
        container = av.open("out.mkv", "w")

        video_stream = container.add_stream("h264", rate=30)
        encoder = video_stream.codec.name

        video_stream.width = input_.streams.video[0].width
        video_stream.height = input_.streams.video[0].height
        video_stream.pix_fmt = "yuv420p"

        for frame in input_.decode(video=0):
            container.mux(video_stream.encode(frame))
            break

        repr = f"{video_stream}"
        assert repr.startswith(f"<av.VideoStream #0 {encoder}, yuv420p 160x120 at ")
        assert repr.endswith(">")

        container.close()
        input_.close()

    def test_printing_video_stream2(self) -> None:
        input_ = av.open(fate_suite("h264/interlaced_crop.mp4"))
        input_stream = input_.streams.video[0]
        container = av.open("out.mkv", "w")

        video_stream = container.add_stream_from_template(input_stream)
        encoder = video_stream.codec.name

        for frame in input_.decode(video=0):
            container.mux(video_stream.encode(frame))
            break

        repr = f"{video_stream}"
        assert repr.startswith(f"<av.VideoStream #0 {encoder}, yuv420p 640x360 at ")
        assert repr.endswith(">")

        container.close()
        input_.close()

    def test_data_stream(self) -> None:
        # First test writing and reading a simple data stream
        container1 = av.open("data.ts", "w")
        data_stream = container1.add_data_stream()

        test_data = [b"test data 1", b"test data 2", b"test data 3"]
        for i, data_ in enumerate(test_data):
            packet = av.Packet(data_)
            packet.pts = i
            packet.stream = data_stream
            container1.mux(packet)
        container1.close()

        # Test reading back the data stream
        container = av.open("data.ts")

        # Test best stream selection
        data = container.streams.best("data")
        assert data == container.streams.data[0]

        # Test get method
        assert [data] == container.streams.get(data=0)
        assert [data] == container.streams.get(data=(0,))

        # Verify we can read back all the packets, ignoring empty ones
        packets = [p for p in container.demux(data) if bytes(p)]
        assert len(packets) == len(test_data)
        for packet, original_data in zip(packets, test_data):
            assert bytes(packet) == original_data

        # Test string representation
        repr = f"{data_stream}"
        assert repr.startswith("<av.DataStream #0") and repr.endswith(">")

        container.close()

    def test_data_stream_from_template(self) -> None:
        source_path = "data_source.ts"
        payloads = [b"payload-a", b"payload-b", b"payload-c"]

        with av.open(source_path, "w") as source:
            source_stream = source.add_data_stream()
            for i, payload in enumerate(payloads):
                packet = av.Packet(payload)
                packet.pts = i
                packet.stream = source_stream
                source.mux(packet)

        copied_payloads: list[bytes] = []

        with av.open(source_path) as input_container:
            input_data_stream = input_container.streams.data[0]

            with av.open("data_copy.ts", "w") as output_container:
                output_data_stream = output_container.add_stream_from_template(
                    input_data_stream
                )

                for packet in input_container.demux(input_data_stream):
                    payload = bytes(packet)
                    if not payload:
                        continue
                    copied_payloads.append(payload)
                    clone = av.Packet(payload)
                    clone.pts = packet.pts
                    clone.dts = packet.dts
                    clone.time_base = packet.time_base
                    clone.stream = output_data_stream
                    output_container.mux(clone)

        with av.open("data_copy.ts") as remuxed:
            output_stream = remuxed.streams.data[0]
            assert output_stream.codec_context is None

            remuxed_payloads: list[bytes] = []
            for packet in remuxed.demux(output_stream):
                payload = bytes(packet)
                if payload:
                    remuxed_payloads.append(payload)

        assert remuxed_payloads == copied_payloads

    def test_attachment_stream(self) -> None:
        input_path = av.datasets.curated(
            "pexels/time-lapse-video-of-night-sky-857195.mp4"
        )
        input_ = av.open(input_path)
        out1_path = "video_with_attachment.mkv"

        with av.open(out1_path, "w") as out1:
            out1.add_attachment(
                name="attachment.txt", mimetype="text/plain", data=b"hello\n"
            )

            in_v = input_.streams.video[0]
            out_v = out1.add_stream_from_template(in_v)

            for packet in input_.demux(in_v):
                if packet.dts is None:
                    continue
                packet.stream = out_v
                out1.mux(packet)

        input_.close()

        with av.open(out1_path) as c:
            attachments = c.streams.attachments
            assert len(attachments) == 1
            att = attachments[0]
            assert att.name == "attachment.txt"
            assert att.mimetype == "text/plain"
            assert att.data == b"hello\n"

        out2_path = "remuxed_attachment.mkv"
        with av.open(out1_path) as ic, av.open(out2_path, "w") as oc:
            stream_map = {}
            for s in ic.streams:
                stream_map[s.index] = oc.add_stream_from_template(s)

            for packet in ic.demux(ic.streams.video):
                if packet.dts is None:
                    continue
                packet.stream = stream_map[packet.stream.index]
                oc.mux(packet)

        with av.open(out2_path) as c:
            attachments = c.streams.attachments
            assert len(attachments) == 1
            att = attachments[0]
            assert att.name == "attachment.txt"
            assert att.mimetype == "text/plain"
            assert att.data == b"hello\n"
