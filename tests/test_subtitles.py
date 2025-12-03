import io
from typing import cast

import av
from av.codec.context import CodecContext
from av.subtitles.codeccontext import SubtitleCodecContext
from av.subtitles.subtitle import AssSubtitle, BitmapSubtitle

from .common import TestCase, fate_suite


class TestSubtitle:
    def test_movtext(self) -> None:
        path = fate_suite("sub/MovText_capability_tester.mp4")

        subs: list[AssSubtitle] = []
        with av.open(path) as container:
            for packet in container.demux():
                subs.extend(cast(list[AssSubtitle], packet.decode()))

        assert len(subs) == 3

        sub = subs[0]
        assert isinstance(sub, AssSubtitle)
        assert sub.type == b"ass"
        assert sub.text == b""
        assert sub.ass == b"0,0,Default,,0,0,0,,- Test 1.\\N- Test 2."
        assert sub.dialogue == b"- Test 1.\n- Test 2."

    def test_subset(self) -> None:
        path = fate_suite("sub/MovText_capability_tester.mp4")

        with av.open(path) as container:
            subs = container.streams.subtitles[0]
            for packet in container.demux(subs):
                subset = subs.decode2(packet)
                if subset is not None:
                    assert not isinstance(subset, av.subtitles.subtitle.Subtitle)
                    assert isinstance(subset, av.subtitles.subtitle.SubtitleSet)
                    assert subset.format == 1
                    assert hasattr(subset, "pts")
                    assert subset.start_display_time == 0
                    assert hasattr(subset, "end_display_time")

    def test_vobsub(self) -> None:
        path = fate_suite("sub/vobsub.sub")

        subs: list[BitmapSubtitle] = []
        with av.open(path) as container:
            for packet in container.demux():
                subs.extend(cast(list[BitmapSubtitle], packet.decode()))

        assert len(subs) == 43

        sub = subs[0]
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

        subs: list[object] = []
        with av.open(path) as container:
            stream = container.streams.subtitles[0]
            for packet in container.demux(stream):
                subs.extend(stream.decode(packet))
                subs.extend(stream.decode())

        assert len(subs) == 3

    def test_subtitle_header_read(self) -> None:
        """Test reading subtitle_header from a decoded subtitle stream."""
        path = fate_suite("sub/MovText_capability_tester.mp4")

        with av.open(path) as container:
            stream = container.streams.subtitles[0]
            ctx = cast(SubtitleCodecContext, stream.codec_context)
            header = ctx.subtitle_header
            assert header is None or isinstance(header, bytes)

    def test_subtitle_header_write(self) -> None:
        """Test setting subtitle_header on encoder context."""
        ctx = cast(SubtitleCodecContext, CodecContext.create("mov_text", "w"))
        assert ctx.subtitle_header is None

        ass_header = b"[Script Info]\nScriptType: v4.00+\n"
        ctx.subtitle_header = ass_header
        assert ctx.subtitle_header == ass_header

        new_header = b"[Script Info]\nScriptType: v4.00\n"
        ctx.subtitle_header = new_header
        assert ctx.subtitle_header == new_header

        ctx.subtitle_header = None
        assert ctx.subtitle_header is None


class TestSubtitleEncoding(TestCase):
    def test_subtitle_set_create(self) -> None:
        """Test creating SubtitleSet for encoding."""
        from av.subtitles.subtitle import SubtitleSet

        text = b"0,0,Default,,0,0,0,,Hello World"
        subtitle = SubtitleSet.create(text=text, start=0, end=2000, pts=0)

        assert subtitle.format == 1
        assert subtitle.start_display_time == 0
        assert subtitle.end_display_time == 2000
        assert subtitle.pts == 0
        assert len(subtitle) == 1
        assert cast(AssSubtitle, subtitle[0]).ass == text

    def test_subtitle_encode_mp4(self) -> None:
        """Test encoding subtitles to MP4 container."""
        from av.subtitles.subtitle import SubtitleSet

        ass_header = b"""[Script Info]
ScriptType: v4.00+
PlayResX: 640
PlayResY: 480

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,20,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,2,2,10,10,10,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""

        output = io.BytesIO()
        with av.open(output, "w", format="mp4") as container:
            # MP4 requires video for subtitles
            video_stream = container.add_stream("libx264", rate=30)
            video_stream.width = 640
            video_stream.height = 480
            video_stream.pix_fmt = "yuv420p"

            sub_stream = container.add_stream("mov_text")
            sub_ctx = cast(SubtitleCodecContext, sub_stream.codec_context)
            sub_ctx.subtitle_header = ass_header

            container.start_encoding()

            frame = av.VideoFrame(640, 480, "yuv420p")
            frame.pts = 0
            for packet in video_stream.encode(frame):
                container.mux(packet)

            time_base = sub_stream.time_base
            assert time_base is not None
            subtitle = SubtitleSet.create(
                text=b"0,0,Default,,0,0,0,,Hello World",
                start=0,
                end=int(2 / time_base),
                pts=0,
            )
            packet = sub_ctx.encode_subtitle(subtitle)
            packet.stream = sub_stream
            container.mux(packet)

            for packet in video_stream.encode():
                container.mux(packet)

        output.seek(0)
        with av.open(output) as container:
            assert len(container.streams.subtitles) == 1

    def test_subtitle_encode_mkv_srt(self) -> None:
        """Test encoding SRT subtitles to MKV container."""
        from av.subtitles.subtitle import SubtitleSet

        minimal_header = b"[Script Info]\n"

        output = io.BytesIO()
        with av.open(output, "w", format="matroska") as container:
            sub_stream = container.add_stream("srt")
            sub_ctx = cast(SubtitleCodecContext, sub_stream.codec_context)
            sub_ctx.subtitle_header = minimal_header

            container.start_encoding()

            time_base = sub_stream.time_base
            assert time_base is not None
            for text, start_sec, duration_sec in [
                (b"0,0,Default,,0,0,0,,First subtitle", 0, 2),
                (b"0,0,Default,,0,0,0,,Second subtitle", 2, 2),
                (b"0,0,Default,,0,0,0,,Third subtitle", 4, 2),
            ]:
                subtitle = SubtitleSet.create(
                    text=text,
                    start=0,
                    end=int(duration_sec / time_base),
                    pts=int(start_sec / time_base),
                )
                packet = sub_ctx.encode_subtitle(subtitle)
                packet.stream = sub_stream
                container.mux(packet)

        output.seek(0)
        with av.open(output, mode="r") as input_container:
            assert len(input_container.streams.subtitles) == 1
            subs: list[AssSubtitle] = []
            for packet in input_container.demux():
                subs.extend(cast(list[AssSubtitle], packet.decode()))
            assert len(subs) == 3
            assert b"First subtitle" in subs[0].dialogue
            assert b"Second subtitle" in subs[1].dialogue
            assert b"Third subtitle" in subs[2].dialogue
