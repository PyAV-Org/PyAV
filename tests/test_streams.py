from fractions import Fraction

import av

from .common import fate_suite


class TestStreams:
    def test_stream_tuples(self) -> None:
        for fate_name in ("h264/interlaced_crop.mp4",):
            container = av.open(fate_suite(fate_name))

            video_streams = tuple([s for s in container.streams if s.type == "video"])
            assert video_streams == container.streams.video

            audio_streams = tuple([s for s in container.streams if s.type == "audio"])
            assert audio_streams == container.streams.audio

    def test_selection(self) -> None:
        container = av.open(
            fate_suite("amv/MTV_high_res_320x240_sample_Penguin_Joke_MTV_from_WMV.amv")
        )
        video = container.streams.video[0]
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

    # def test_side_data(self) -> None:
    #     container = av.open(fate_suite("mov/displaymatrix.mov"))
    #     video = container.streams.video[0]

    #     assert video.nb_side_data == 1
    #     assert video.side_data["DISPLAYMATRIX"] == -90.0
