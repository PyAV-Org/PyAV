import av
from av.subtitles.subtitle import AssSubtitle, BitmapSubtitle

from .common import fate_suite


class TestSubtitle:
    def test_movtext(self) -> None:
        path = fate_suite("sub/MovText_capability_tester.mp4")

        subs = []
        with av.open(path) as container:
            for packet in container.demux():
                subs.extend(packet.decode())

        assert len(subs) == 3

        subset = subs[0]
        assert subset.format == 1
        assert subset.pts == 970000
        assert subset.start_display_time == 0
        assert subset.end_display_time == 1570

        sub = subset[0]
        assert isinstance(sub, AssSubtitle)
        assert sub.type == b"ass"
        assert sub.text == b""
        assert sub.ass == b"0,0,Default,,0,0,0,,- Test 1.\\N- Test 2."
        assert sub.dialogue == b"- Test 1.\n- Test 2."

    def test_vobsub(self) -> None:
        path = fate_suite("sub/vobsub.sub")

        subs = []
        with av.open(path) as container:
            for packet in container.demux():
                subs.extend(packet.decode())

        assert len(subs) == 43

        subset = subs[0]
        assert subset.format == 0
        assert subset.pts == 132499044
        assert subset.start_display_time == 0
        assert subset.end_display_time == 4960

        sub = subset[0]
        assert isinstance(sub, BitmapSubtitle)
        assert sub.type == b"bitmap"
        assert sub.x == 259
        assert sub.y == 379
        assert sub.width == 200
        assert sub.height == 24
        assert sub.nb_colors == 4

        bms = sub.planes
        assert len(bms) == 1
        assert len(memoryview(bms[0])) == 4800  # type: ignore

    def test_subtitle_flush(self) -> None:
        path = fate_suite("sub/MovText_capability_tester.mp4")

        subs = []
        with av.open(path) as container:
            stream = container.streams.subtitles[0]
            for packet in container.demux(stream):
                subs.extend(stream.decode(packet))
                subs.extend(stream.decode())

        assert len(subs) == 3
