from fractions import Fraction

import av

from .common import TestCase, fate_suite


class TestAudioProbe(TestCase):
    def setUp(self):
        self.file = av.open(fate_suite("aac/latm_stereo_to_51.ts"))

    def test_container_probing(self) -> None:
        assert self.file.bit_rate == 269558
        assert self.file.duration == 6165333
        assert str(self.file.format) == "<av.ContainerFormat 'mpegts'>"
        assert self.file.format.name == "mpegts"
        assert self.file.format.long_name == "MPEG-TS (MPEG-2 Transport Stream)"
        assert self.file.metadata == {}
        assert self.file.size == 207740
        assert self.file.start_time == 1400000
        assert len(self.file.streams) == 1

    def test_stream_probing(self) -> None:
        stream = self.file.streams[0]

        assert isinstance(stream, av.AudioStream)
        assert str(stream).startswith(
            "<av.AudioStream #0 aac_latm at 48000Hz, stereo, fltp at "
        )

        # actual stream properties
        assert stream.duration == 554880
        assert stream.frames == 0
        assert stream.id == 256
        assert stream.index == 0
        assert stream.language == "eng"
        assert stream.metadata == {"language": "eng"}
        assert stream.profile == "LC"
        assert stream.start_time == 126000
        assert stream.time_base == Fraction(1, 90000)
        assert stream.type == "audio"

        # codec context properties
        assert stream.bit_rate is None
        assert stream.channels == 2
        assert stream.codec.name == "aac_latm"
        assert stream.codec.long_name == "AAC LATM (Advanced Audio Coding LATM syntax)"
        assert stream.format.bits == 32
        assert stream.format.name == "fltp"
        assert stream.layout.name == "stereo"
        assert stream.max_bit_rate is None
        assert stream.sample_rate == 48000


class TestAudioProbeCorrupt(TestCase):
    def setUp(self) -> None:
        # write an empty file
        path = self.sandboxed("empty.flac")
        with open(path, "wb"):
            pass

        self.file = av.open(path, "r")

    def test_container_probing(self) -> None:
        assert self.file.bit_rate == 0
        assert self.file.duration is None
        assert str(self.file.format) == "<av.ContainerFormat 'flac'>"
        assert self.file.format.name == "flac"
        assert self.file.format.long_name == "raw FLAC"
        assert self.file.metadata == {}
        assert self.file.size == 0
        assert self.file.start_time is None
        assert len(self.file.streams) == 1

    def test_stream_probing(self) -> None:
        stream = self.file.streams[0]

        assert isinstance(stream, av.AudioStream)
        assert str(stream).startswith(
            "<av.AudioStream #0 flac at 0Hz, 0 channels, None at "
        )

        # actual stream properties
        assert stream.duration is None
        assert stream.frames == 0
        assert stream.id == 0
        assert stream.index == 0
        assert stream.language is None
        assert stream.metadata == {}
        assert stream.profile is None
        assert stream.start_time is None
        assert stream.time_base == Fraction(1, 90000)
        assert stream.type == "audio"

        # codec context properties
        assert stream.bit_rate is None
        assert stream.codec.name == "flac"
        assert stream.codec.long_name == "FLAC (Free Lossless Audio Codec)"
        assert stream.channels == 0
        assert stream.format is None
        assert stream.layout.name == "0 channels"
        assert stream.max_bit_rate is None
        assert stream.sample_rate == 0


class TestDataProbe(TestCase):
    def setUp(self) -> None:
        self.file = av.open(fate_suite("mxf/track_01_v02.mxf"))

    def test_container_probing(self) -> None:
        assert self.file.bit_rate == 27872687
        assert self.file.duration == 417083
        assert str(self.file.format) == "<av.ContainerFormat 'mxf'>"
        assert self.file.format.name == "mxf"
        assert self.file.format.long_name == "MXF (Material eXchange Format)"
        assert self.file.size == 1453153
        assert self.file.start_time == 0
        assert len(self.file.streams) == 4

        for key, value in (
            ("application_platform", "AAFSDK (MacOS X)"),
            ("comment_Comments", "example comment"),
            ("comment_UNC Path", "/Users/mark/Desktop/dnxhr_tracknames_export.aaf"),
            ("company_name", "Avid Technology, Inc."),
            ("generation_uid", "b6bcfcab-70ff-7331-c592-233869de11d2"),
            ("material_package_name", "Example.new.04"),
            (
                "material_package_umid",
                "0x060A2B340101010101010F001300000057E19D16BA8202DB060E2B347F7F2A80",
            ),
            ("modification_date", "2016-09-20T20:33:26.000000Z"),
            ("operational_pattern_ul", "060e2b34.04010102.0d010201.10030000"),
            ("product_name", "Avid Media Composer 8.6.3.43955"),
            ("product_uid", "acfbf03a-4f42-a231-d0b7-c06ecd3d4ad7"),
            ("product_version", "Unknown version"),
            ("project_name", "UHD"),
            ("uid", "4482d537-4203-ea40-9e4e-08a22900dd39"),
        ):
            assert self.file.metadata.get(key) == value

    def test_stream_probing(self) -> None:
        stream = self.file.streams[0]

        assert str(stream).startswith("<av.DataStream #0 data/<nocodec> at ")

        assert stream.duration == 37537
        assert stream.frames == 0
        assert stream.id == 1
        assert stream.index == 0
        assert stream.language is None
        assert stream.metadata == {
            "data_type": "video",
            "file_package_umid": "0x060A2B340101010101010F001300000057E19D16BA8302DB060E2B347F7F2A80",
            "track_name": "Base",
        }
        assert stream.profile is None
        assert stream.start_time == 0
        assert stream.time_base == Fraction(1, 90000)
        assert stream.type == "data"
        assert not hasattr(stream, "codec")


class TestSubtitleProbe(TestCase):
    def setUp(self) -> None:
        self.file = av.open(fate_suite("sub/MovText_capability_tester.mp4"))

    def test_container_probing(self) -> None:
        assert self.file.bit_rate == 810
        assert self.file.duration == 8140000
        assert str(self.file.format) == "<av.ContainerFormat 'mov,mp4,m4a,3gp,3g2,mj2'>"
        assert self.file.format.name == "mov,mp4,m4a,3gp,3g2,mj2"
        assert self.file.format.long_name == "QuickTime / MOV"
        assert self.file.metadata == {
            "compatible_brands": "isom",
            "creation_time": "2012-07-04T05:10:41.000000Z",
            "major_brand": "isom",
            "minor_version": "1",
        }
        assert self.file.size == 825
        assert self.file.start_time is None
        assert len(self.file.streams) == 1

    def test_stream_probing(self) -> None:
        stream = self.file.streams[0]

        assert str(stream).startswith("<av.SubtitleStream #0 subtitle/mov_text at ")

        # actual stream properties
        assert stream.duration == 8140
        assert stream.frames == 6
        assert stream.id == 1
        assert stream.index == 0
        assert stream.language == "und"
        assert stream.metadata == {
            "creation_time": "2012-07-04T05:10:41.000000Z",
            "handler_name": "reference.srt - Imported with GPAC 0.4.6-DEV-rev4019",
            "language": "und",
        }
        assert stream.profile is None
        assert stream.start_time is None
        assert stream.time_base == Fraction(1, 1000)
        assert stream.type == "subtitle"

        # codec context properties
        assert stream.codec.name == "mov_text"
        assert stream.codec.long_name == "3GPP Timed Text subtitle"


class TestVideoProbe(TestCase):
    def setUp(self) -> None:
        self.file = av.open(fate_suite("mpeg2/mpeg2_field_encoding.ts"))

    def test_container_probing(self) -> None:
        assert self.file.bit_rate == 3950617
        assert self.file.duration == 1620000
        assert str(self.file.format) == "<av.ContainerFormat 'mpegts'>"
        assert self.file.format.name == "mpegts"
        assert self.file.format.long_name == "MPEG-TS (MPEG-2 Transport Stream)"
        assert self.file.metadata == {}
        assert self.file.size == 800000
        assert self.file.start_time == 22953408322
        assert len(self.file.streams) == 1

    def test_stream_probing(self) -> None:
        stream = self.file.streams[0]

        assert isinstance(stream, av.video.stream.VideoStream)
        assert str(stream).startswith(
            "<av.VideoStream #0 mpeg2video, yuv420p 720x576 at "
        )

        # actual stream properties
        assert stream.average_rate == Fraction(25, 1)
        assert stream.duration == 145800
        assert stream.frames == 0
        assert stream.id == 4131
        assert stream.index == 0
        assert stream.language is None
        assert stream.metadata == {}
        assert stream.profile == "Simple"
        assert stream.start_time == 2065806749
        assert stream.time_base == Fraction(1, 90000)
        assert stream.type == "video"

        # codec context properties
        assert stream.bit_rate == 3364800
        assert stream.codec.long_name == "MPEG-2 video"
        assert stream.codec.name == "mpeg2video"
        assert stream.display_aspect_ratio == Fraction(4, 3)
        assert stream.format.name == "yuv420p"
        assert not stream.has_b_frames
        assert stream.height == 576
        assert stream.max_bit_rate is None
        assert stream.sample_aspect_ratio == Fraction(16, 15)
        assert stream.width == 720
        assert stream.coded_width == 0
        assert stream.coded_height == 0

        assert not hasattr(stream, "framerate")
        assert not hasattr(stream, "rate")


class TestVideoProbeCorrupt(TestCase):
    def setUp(self) -> None:
        path = self.sandboxed("empty.h264")
        with open(path, "wb"):
            pass

        self.file = av.open(path)

    def test_container_probing(self) -> None:
        assert str(self.file.format) == "<av.ContainerFormat 'h264'>"
        assert self.file.format.name == "h264"
        assert self.file.format.long_name == "raw H.264 video"
        assert self.file.size == 0
        assert self.file.bit_rate == 0
        assert self.file.duration is None

        assert len(self.file.streams) == 1
        assert self.file.start_time is None
        assert self.file.metadata == {}

    def test_stream_probing(self) -> None:
        stream = self.file.streams[0]

        assert isinstance(stream, av.VideoStream)
        assert str(stream).startswith("<av.VideoStream #0 h264, None 0x0 at ")

        # actual stream properties
        assert stream.type == "video"
        assert stream.duration is None
        assert stream.frames == 0
        assert stream.id == 0
        assert stream.index == 0
        assert stream.language is None
        assert stream.metadata == {}
        assert stream.profile is None
        assert stream.start_time is None
        assert stream.time_base == Fraction(1, 1200000)

        # codec context properties
        assert stream.bit_rate is None
        assert stream.codec.long_name == "H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10"
        assert stream.codec.name == "h264"
        assert stream.display_aspect_ratio is None
        assert stream.format is None
        assert not stream.has_b_frames
        assert stream.height == 0
        assert stream.max_bit_rate is None
        assert stream.sample_aspect_ratio is None
        assert stream.width == 0

        assert stream.coded_width == 0
        assert stream.coded_height == 0
