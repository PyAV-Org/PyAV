import warnings
from fractions import Fraction

import av

from .common import TestCase, fate_suite


class TestAudioProbe(TestCase):
    def setUp(self):
        self.file = av.open(fate_suite("aac/latm_stereo_to_51.ts"))

    def test_container_probing(self):
        self.assertEqual(self.file.bit_rate, 269558)
        self.assertEqual(self.file.duration, 6165333)
        self.assertEqual(str(self.file.format), "<av.ContainerFormat 'mpegts'>")
        self.assertEqual(self.file.format.name, "mpegts")
        self.assertEqual(
            self.file.format.long_name, "MPEG-TS (MPEG-2 Transport Stream)"
        )
        self.assertEqual(self.file.metadata, {})
        self.assertEqual(self.file.size, 207740)
        self.assertEqual(self.file.start_time, 1400000)
        self.assertEqual(len(self.file.streams), 1)

    def test_stream_probing(self):
        stream = self.file.streams[0]

        # check __repr__
        self.assertTrue(
            str(stream).startswith(
                "<av.AudioStream #0 aac_latm at 48000Hz, stereo, fltp at "
            )
        )

        # actual stream properties
        self.assertEqual(stream.average_rate, None)
        self.assertEqual(stream.base_rate, None)
        self.assertEqual(stream.guessed_rate, None)
        self.assertEqual(stream.duration, 554880)
        self.assertEqual(stream.frames, 0)
        self.assertEqual(stream.id, 256)
        self.assertEqual(stream.index, 0)
        self.assertEqual(stream.language, "eng")
        self.assertEqual(
            stream.metadata,
            {
                "language": "eng",
            },
        )
        self.assertEqual(stream.profile, "LC")
        self.assertEqual(stream.start_time, 126000)
        self.assertEqual(stream.time_base, Fraction(1, 90000))
        self.assertEqual(stream.type, "audio")

        # codec context properties
        self.assertEqual(stream.bit_rate, None)
        self.assertEqual(stream.channels, 2)
        self.assertEqual(stream.codec.name, "aac_latm")
        self.assertEqual(
            stream.codec.long_name, "AAC LATM (Advanced Audio Coding LATM syntax)"
        )
        self.assertEqual(stream.format.bits, 32)
        self.assertEqual(stream.format.name, "fltp")
        self.assertEqual(stream.layout.name, "stereo")
        self.assertEqual(stream.max_bit_rate, None)
        self.assertEqual(stream.sample_rate, 48000)


class TestAudioProbeCorrupt(TestCase):
    def setUp(self):
        # write an empty file
        path = self.sandboxed("empty.flac")
        with open(path, "wb"):
            pass

        self.file = av.open(path)

    def test_container_probing(self):
        self.assertEqual(self.file.bit_rate, 0)
        self.assertEqual(self.file.duration, None)
        self.assertEqual(str(self.file.format), "<av.ContainerFormat 'flac'>")
        self.assertEqual(self.file.format.name, "flac")
        self.assertEqual(self.file.format.long_name, "raw FLAC")
        self.assertEqual(self.file.metadata, {})
        self.assertEqual(self.file.size, 0)
        self.assertEqual(self.file.start_time, None)
        self.assertEqual(len(self.file.streams), 1)

    def test_stream_probing(self):
        stream = self.file.streams[0]

        # ensure __repr__ does not crash
        self.assertTrue(
            str(stream).startswith(
                "<av.AudioStream #0 flac at 0Hz, 0 channels, None at "
            )
        )

        # actual stream properties
        self.assertEqual(stream.average_rate, None)
        self.assertEqual(stream.base_rate, None)
        self.assertEqual(stream.guessed_rate, None)
        self.assertEqual(stream.duration, None)
        self.assertEqual(stream.frames, 0)
        self.assertEqual(stream.id, 0)
        self.assertEqual(stream.index, 0)
        self.assertEqual(stream.language, None)
        self.assertEqual(stream.metadata, {})
        self.assertEqual(stream.profile, None)
        self.assertEqual(stream.start_time, None)
        self.assertEqual(stream.time_base, Fraction(1, 90000))
        self.assertEqual(stream.type, "audio")

        # codec context properties
        self.assertEqual(stream.bit_rate, None)
        self.assertEqual(stream.codec.name, "flac")
        self.assertEqual(stream.codec.long_name, "FLAC (Free Lossless Audio Codec)")
        self.assertEqual(stream.channels, 0)
        self.assertEqual(stream.format, None)
        self.assertEqual(stream.layout.name, "0 channels")
        self.assertEqual(stream.max_bit_rate, None)
        self.assertEqual(stream.sample_rate, 0)


class TestDataProbe(TestCase):
    def setUp(self):
        self.file = av.open(fate_suite("mxf/track_01_v02.mxf"))

    def test_container_probing(self):
        self.assertEqual(self.file.bit_rate, 27872687)
        self.assertEqual(self.file.duration, 417083)
        self.assertEqual(str(self.file.format), "<av.ContainerFormat 'mxf'>")
        self.assertEqual(self.file.format.name, "mxf")
        self.assertEqual(self.file.format.long_name, "MXF (Material eXchange Format)")
        self.assertEqual(self.file.size, 1453153)
        self.assertEqual(self.file.start_time, 0)
        self.assertEqual(len(self.file.streams), 4)

        for key, value, min_version in (
            ("application_platform", "AAFSDK (MacOS X)", None),
            ("comment_Comments", "example comment", None),
            (
                "comment_UNC Path",
                "/Users/mark/Desktop/dnxhr_tracknames_export.aaf",
                None,
            ),
            ("company_name", "Avid Technology, Inc.", None),
            ("generation_uid", "b6bcfcab-70ff-7331-c592-233869de11d2", None),
            ("material_package_name", "Example.new.04", None),
            (
                "material_package_umid",
                "0x060A2B340101010101010F001300000057E19D16BA8202DB060E2B347F7F2A80",
                None,
            ),
            ("modification_date", "2016-09-20T20:33:26.000000Z", None),
            # Next one is FFmpeg >= 4.2.
            (
                "operational_pattern_ul",
                "060e2b34.04010102.0d010201.10030000",
                {"libavformat": (58, 29)},
            ),
            ("product_name", "Avid Media Composer 8.6.3.43955", None),
            ("product_uid", "acfbf03a-4f42-a231-d0b7-c06ecd3d4ad7", None),
            ("product_version", "Unknown version", None),
            ("project_name", "UHD", None),
            ("uid", "4482d537-4203-ea40-9e4e-08a22900dd39", None),
        ):
            if min_version and any(
                av.library_versions[name] < version
                for name, version in min_version.items()
            ):
                continue
            self.assertEqual(self.file.metadata.get(key), value)

    def test_stream_probing(self):
        stream = self.file.streams[0]

        # check __repr__
        self.assertTrue(str(stream).startswith("<av.DataStream #0 data/<nocodec> at "))

        # actual stream properties
        self.assertEqual(stream.average_rate, None)
        self.assertEqual(stream.base_rate, None)
        self.assertEqual(stream.guessed_rate, None)
        self.assertEqual(stream.duration, 37537)
        self.assertEqual(stream.frames, 0)
        self.assertEqual(stream.id, 1)
        self.assertEqual(stream.index, 0)
        self.assertEqual(stream.language, None)
        self.assertEqual(
            stream.metadata,
            {
                "data_type": "video",
                "file_package_umid": "0x060A2B340101010101010F001300000057E19D16BA8302DB060E2B347F7F2A80",
                "track_name": "Base",
            },
        )
        self.assertEqual(stream.profile, None)
        self.assertEqual(stream.start_time, 0)
        self.assertEqual(stream.time_base, Fraction(1, 90000))
        self.assertEqual(stream.type, "data")

        # codec context properties
        self.assertEqual(stream.codec, None)


class TestSubtitleProbe(TestCase):
    def setUp(self):
        self.file = av.open(fate_suite("sub/MovText_capability_tester.mp4"))

    def test_container_probing(self):
        self.assertEqual(self.file.bit_rate, 810)
        self.assertEqual(self.file.duration, 8140000)
        self.assertEqual(
            str(self.file.format), "<av.ContainerFormat 'mov,mp4,m4a,3gp,3g2,mj2'>"
        )
        self.assertEqual(self.file.format.name, "mov,mp4,m4a,3gp,3g2,mj2")
        self.assertEqual(self.file.format.long_name, "QuickTime / MOV")
        self.assertEqual(
            self.file.metadata,
            {
                "compatible_brands": "isom",
                "creation_time": "2012-07-04T05:10:41.000000Z",
                "major_brand": "isom",
                "minor_version": "1",
            },
        )
        self.assertEqual(self.file.size, 825)
        self.assertEqual(self.file.start_time, None)
        self.assertEqual(len(self.file.streams), 1)

    def test_stream_probing(self):
        stream = self.file.streams[0]

        # check __repr__
        self.assertTrue(
            str(stream).startswith("<av.SubtitleStream #0 subtitle/mov_text at ")
        )

        # actual stream properties
        self.assertEqual(stream.average_rate, None)
        self.assertEqual(stream.duration, 8140)
        self.assertEqual(stream.frames, 6)
        self.assertEqual(stream.id, 1)
        self.assertEqual(stream.index, 0)
        self.assertEqual(stream.language, "und")
        self.assertEqual(
            stream.metadata,
            {
                "creation_time": "2012-07-04T05:10:41.000000Z",
                "handler_name": "reference.srt - Imported with GPAC 0.4.6-DEV-rev4019",
                "language": "und",
            },
        )
        self.assertEqual(stream.profile, None)
        self.assertEqual(stream.start_time, None)
        self.assertEqual(stream.time_base, Fraction(1, 1000))
        self.assertEqual(stream.type, "subtitle")

        # codec context properties
        self.assertEqual(stream.codec.name, "mov_text")
        self.assertEqual(stream.codec.long_name, "3GPP Timed Text subtitle")


class TestVideoProbe(TestCase):
    def setUp(self):
        self.file = av.open(fate_suite("mpeg2/mpeg2_field_encoding.ts"))

    def test_container_probing(self):
        self.assertEqual(self.file.bit_rate, 3950617)
        self.assertEqual(self.file.duration, 1620000)
        self.assertEqual(str(self.file.format), "<av.ContainerFormat 'mpegts'>")
        self.assertEqual(self.file.format.name, "mpegts")
        self.assertEqual(
            self.file.format.long_name, "MPEG-TS (MPEG-2 Transport Stream)"
        )
        self.assertEqual(self.file.metadata, {})
        self.assertEqual(self.file.size, 800000)
        self.assertEqual(self.file.start_time, 22953408322)
        self.assertEqual(len(self.file.streams), 1)

    def test_stream_probing(self):
        stream = self.file.streams[0]

        # check __repr__
        self.assertTrue(
            str(stream).startswith("<av.VideoStream #0 mpeg2video, yuv420p 720x576 at ")
        )

        # actual stream properties
        self.assertEqual(stream.average_rate, Fraction(25, 1))
        self.assertEqual(stream.duration, 145800)
        self.assertEqual(stream.frames, 0)
        self.assertEqual(stream.id, 4131)
        self.assertEqual(stream.index, 0)
        self.assertEqual(stream.language, None)
        self.assertEqual(stream.metadata, {})
        self.assertEqual(stream.profile, "Simple")
        self.assertEqual(stream.start_time, 2065806749)
        self.assertEqual(stream.time_base, Fraction(1, 90000))
        self.assertEqual(stream.type, "video")

        # codec context properties
        self.assertEqual(stream.bit_rate, 3364800)
        self.assertEqual(stream.codec.long_name, "MPEG-2 video")
        self.assertEqual(stream.codec.name, "mpeg2video")
        self.assertEqual(stream.display_aspect_ratio, Fraction(4, 3))
        self.assertEqual(stream.format.name, "yuv420p")
        self.assertFalse(stream.has_b_frames)
        self.assertEqual(stream.height, 576)
        self.assertEqual(stream.max_bit_rate, None)
        self.assertEqual(stream.sample_aspect_ratio, Fraction(16, 15))
        self.assertEqual(stream.width, 720)

        # For some reason, these behave differently on OS X (@mikeboers) and
        # Ubuntu (Travis). We think it is FFmpeg, but haven't been able to
        # confirm.
        self.assertIn(stream.coded_width, (720, 0))
        self.assertIn(stream.coded_height, (576, 0))

        # Deprecated properties.
        with warnings.catch_warnings(record=True) as captured:
            stream.framerate
            self.assertEqual(
                captured[0].message.args[0],
                "VideoStream.framerate is deprecated as it is not always set; please use VideoStream.average_rate.",
            )
        with warnings.catch_warnings(record=True) as captured:
            stream.rate
            self.assertEqual(
                captured[0].message.args[0],
                "VideoStream.rate is deprecated as it is not always set; please use VideoStream.average_rate.",
            )


class TestVideoProbeCorrupt(TestCase):
    def setUp(self):
        path = self.sandboxed("empty.h264")
        with open(path, "wb"):
            pass

        self.file = av.open(path)

    def test_container_probing(self):
        self.assertEqual(str(self.file.format), "<av.ContainerFormat 'h264'>")
        self.assertEqual(self.file.format.name, "h264")
        self.assertEqual(self.file.format.long_name, "raw H.264 video")
        self.assertEqual(self.file.size, 0)
        self.assertEqual(self.file.bit_rate, 0)
        self.assertEqual(self.file.duration, None)

        self.assertEqual(len(self.file.streams), 1)
        self.assertEqual(self.file.start_time, None)
        self.assertEqual(self.file.metadata, {})

    def test_stream_probing(self):
        stream = self.file.streams[0]

        # ensure __repr__ does not crash
        self.assertTrue(str(stream).startswith("<av.VideoStream #0 h264, None 0x0 at "))

        # actual stream properties
        self.assertEqual(stream.duration, None)
        self.assertEqual(stream.frames, 0)
        self.assertEqual(stream.id, 0)
        self.assertEqual(stream.index, 0)
        self.assertEqual(stream.language, None)
        self.assertEqual(stream.metadata, {})
        self.assertEqual(stream.profile, None)
        self.assertEqual(stream.start_time, None)
        self.assertEqual(stream.time_base, Fraction(1, 1200000))
        self.assertEqual(stream.type, "video")

        # codec context properties
        self.assertEqual(stream.bit_rate, None)
        self.assertEqual(
            stream.codec.long_name, "H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10"
        )
        self.assertEqual(stream.codec.name, "h264")
        self.assertEqual(stream.display_aspect_ratio, None)
        self.assertEqual(stream.format, None)
        self.assertFalse(stream.has_b_frames)
        self.assertEqual(stream.height, 0)
        self.assertEqual(stream.max_bit_rate, None)
        self.assertEqual(stream.sample_aspect_ratio, None)
        self.assertEqual(stream.width, 0)

        self.assertEqual(stream.coded_width, 0)
        self.assertEqual(stream.coded_height, 0)
