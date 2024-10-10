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

    # def test_side_data(self) -> None:
    #     container = av.open(fate_suite("mov/displaymatrix.mov"))
    #     video = container.streams.video[0]

    #     assert video.nb_side_data == 1
    #     assert video.side_data["DISPLAYMATRIX"] == -90.0
