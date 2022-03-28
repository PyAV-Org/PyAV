from fractions import Fraction
from unittest import SkipTest
import os
import warnings

from av import AudioResampler, Codec, Packet
from av.codec.codec import UnknownCodecError
from av.video.frame import PictureType
import av

from .common import TestCase, fate_suite


def iter_frames(container, stream):
    for packet in container.demux(stream):
        for frame in packet.decode():
            yield frame


def iter_raw_frames(path, packet_sizes, ctx):
    with open(path, "rb") as f:
        for i, size in enumerate(packet_sizes):
            packet = Packet(size)
            read_size = f.readinto(packet)
            assert size
            assert read_size == size
            if not read_size:
                break
            for frame in ctx.decode(packet):
                yield frame
        while True:
            try:
                frames = ctx.decode(None)
            except EOFError:
                break
            for frame in frames:
                yield frame
            if not frames:
                break


class TestCodecContext(TestCase):
    def test_skip_frame_default(self):
        ctx = Codec("png", "w").create()
        self.assertEqual(ctx.skip_frame.name, "DEFAULT")

    def test_codec_tag(self):
        ctx = Codec("mpeg4", "w").create()
        self.assertEqual(ctx.codec_tag, "\x00\x00\x00\x00")
        ctx.codec_tag = "xvid"
        self.assertEqual(ctx.codec_tag, "xvid")

        # wrong length
        with self.assertRaises(ValueError) as cm:
            ctx.codec_tag = "bob"
        self.assertEqual(str(cm.exception), "Codec tag should be a 4 character string.")

        # wrong type
        with self.assertRaises(ValueError) as cm:
            ctx.codec_tag = 123
        self.assertEqual(str(cm.exception), "Codec tag should be a 4 character string.")

        with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
            self.assertEqual(container.streams[0].codec_tag, "avc1")

    def test_decoder_extradata(self):
        ctx = av.codec.Codec("h264", "r").create()
        self.assertEqual(ctx.extradata, None)
        self.assertEqual(ctx.extradata_size, 0)

        ctx.extradata = b"123"
        self.assertEqual(ctx.extradata, b"123")
        self.assertEqual(ctx.extradata_size, 3)

        ctx.extradata = b"54321"
        self.assertEqual(ctx.extradata, b"54321")
        self.assertEqual(ctx.extradata_size, 5)

        ctx.extradata = None
        self.assertEqual(ctx.extradata, None)
        self.assertEqual(ctx.extradata_size, 0)

    def test_decoder_timebase(self):
        ctx = av.codec.Codec("h264", "r").create()

        with warnings.catch_warnings(record=True) as captured:
            self.assertIsNone(ctx.time_base)
            self.assertEqual(
                captured[0].message.args[0],
                "Using CodecContext.time_base for decoders is deprecated.",
            )

        with warnings.catch_warnings(record=True) as captured:
            ctx.time_base = Fraction(1, 25)
            self.assertEqual(
                captured[0].message.args[0],
                "Using CodecContext.time_base for decoders is deprecated.",
            )

    def test_encoder_extradata(self):
        ctx = av.codec.Codec("h264", "w").create()
        self.assertEqual(ctx.extradata, None)
        self.assertEqual(ctx.extradata_size, 0)

        with self.assertRaises(ValueError) as cm:
            ctx.extradata = b"123"
        self.assertEqual(str(cm.exception), "Can only set extradata for decoders.")

    def test_encoder_pix_fmt(self):
        ctx = av.codec.Codec("h264", "w").create()

        # valid format
        ctx.pix_fmt = "yuv420p"
        self.assertEqual(ctx.pix_fmt, "yuv420p")

        # invalid format
        with self.assertRaises(ValueError) as cm:
            ctx.pix_fmt = "__unknown_pix_fmt"
        self.assertEqual(str(cm.exception), "not a pixel format: '__unknown_pix_fmt'")
        self.assertEqual(ctx.pix_fmt, "yuv420p")

    def test_parse(self):

        # This one parses into a single packet.
        self._assert_parse("mpeg4", fate_suite("h264/interlaced_crop.mp4"))

        # This one parses into many small packets.
        self._assert_parse("mpeg2video", fate_suite("mpeg2/mpeg2_field_encoding.ts"))

    def _assert_parse(self, codec_name, path):

        fh = av.open(path)
        packets = []
        for packet in fh.demux(video=0):
            packets.append(packet)

        full_source = b"".join(bytes(p) for p in packets)

        for size in 1024, 8192, 65535:

            ctx = Codec(codec_name).create()
            packets = []

            for i in range(0, len(full_source), size):
                block = full_source[i : i + size]
                packets.extend(ctx.parse(block))
            packets.extend(ctx.parse())

            parsed_source = b"".join(bytes(p) for p in packets)
            self.assertEqual(len(parsed_source), len(full_source))
            self.assertEqual(full_source, parsed_source)


class TestEncoding(TestCase):
    def test_encoding_png(self):
        self.image_sequence_encode("png")

    def test_encoding_mjpeg(self):
        self.image_sequence_encode("mjpeg")

    def test_encoding_tiff(self):
        self.image_sequence_encode("tiff")

    def image_sequence_encode(self, codec_name):

        try:
            codec = Codec(codec_name, "w")
        except UnknownCodecError:
            raise SkipTest()

        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        video_stream = container.streams.video[0]

        width = 640
        height = 480

        ctx = codec.create()

        pix_fmt = ctx.codec.video_formats[0].name

        ctx.width = width
        ctx.height = height
        ctx.time_base = video_stream.codec_context.time_base
        ctx.pix_fmt = pix_fmt
        ctx.open()

        frame_count = 1
        path_list = []
        for frame in iter_frames(container, video_stream):

            new_frame = frame.reformat(width, height, pix_fmt)
            new_packets = ctx.encode(new_frame)

            self.assertEqual(len(new_packets), 1)
            new_packet = new_packets[0]

            path = self.sandboxed(
                "%s/encoder.%04d.%s"
                % (
                    codec_name,
                    frame_count,
                    codec_name if codec_name != "mjpeg" else "jpg",
                )
            )
            path_list.append(path)
            with open(path, "wb") as f:
                f.write(new_packet)
            frame_count += 1
            if frame_count > 5:
                break

        ctx = av.Codec(codec_name, "r").create()

        for path in path_list:
            with open(path, "rb") as f:
                size = os.fstat(f.fileno()).st_size
                packet = Packet(size)
                size = f.readinto(packet)
                frame = ctx.decode(packet)[0]
                self.assertEqual(frame.width, width)
                self.assertEqual(frame.height, height)
                self.assertEqual(frame.format.name, pix_fmt)

    def test_encoding_h264(self):
        self.video_encoding("libx264", {"crf": "19"})

    def test_encoding_mpeg4(self):
        self.video_encoding("mpeg4")

    def test_encoding_xvid(self):
        self.video_encoding("mpeg4", codec_tag="xvid")

    def test_encoding_mpeg1video(self):
        self.video_encoding("mpeg1video")

    def test_encoding_dvvideo(self):
        options = {"pix_fmt": "yuv411p", "width": 720, "height": 480}
        self.video_encoding("dvvideo", options)

    def test_encoding_dnxhd(self):
        options = {
            "b": "90M",  # bitrate
            "pix_fmt": "yuv422p",
            "width": 1920,
            "height": 1080,
            "time_base": "1001/30000",
            "max_frames": 5,
        }
        self.video_encoding("dnxhd", options)

    def video_encoding(self, codec_name, options={}, codec_tag=None):

        try:
            codec = Codec(codec_name, "w")
        except UnknownCodecError:
            raise SkipTest()

        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        video_stream = container.streams.video[0]

        pix_fmt = options.pop("pix_fmt", "yuv420p")
        width = options.pop("width", 640)
        height = options.pop("height", 480)
        max_frames = options.pop("max_frames", 50)
        time_base = options.pop("time_base", video_stream.codec_context.time_base)

        ctx = codec.create()
        ctx.width = width
        ctx.height = height
        ctx.time_base = time_base
        ctx.framerate = 1 / ctx.time_base
        ctx.pix_fmt = pix_fmt
        ctx.options = options  # TODO
        if codec_tag:
            ctx.codec_tag = codec_tag
        ctx.open()

        path = self.sandboxed("encoder.%s" % codec_name)
        packet_sizes = []
        frame_count = 0

        with open(path, "wb") as f:

            for frame in iter_frames(container, video_stream):

                new_frame = frame.reformat(width, height, pix_fmt)

                # reset the picture type
                new_frame.pict_type = PictureType.NONE

                for packet in ctx.encode(new_frame):
                    packet_sizes.append(packet.size)
                    f.write(packet)

                frame_count += 1
                if frame_count >= max_frames:
                    break

            for packet in ctx.encode(None):
                packet_sizes.append(packet.size)
                f.write(packet)

        dec_codec_name = codec_name
        if codec_name == "libx264":
            dec_codec_name = "h264"

        ctx = av.Codec(dec_codec_name, "r").create()
        ctx.open()

        decoded_frame_count = 0
        for frame in iter_raw_frames(path, packet_sizes, ctx):
            decoded_frame_count += 1
            self.assertEqual(frame.width, width)
            self.assertEqual(frame.height, height)
            self.assertEqual(frame.format.name, pix_fmt)

        self.assertEqual(frame_count, decoded_frame_count)

    def test_encoding_pcm_s24le(self):
        self.audio_encoding("pcm_s24le")

    def test_encoding_aac(self):
        self.audio_encoding("aac")

    def test_encoding_mp2(self):
        self.audio_encoding("mp2")

    def audio_encoding(self, codec_name):

        try:
            codec = Codec(codec_name, "w")
        except UnknownCodecError:
            raise SkipTest()

        ctx = codec.create()
        if ctx.codec.experimental:
            raise SkipTest()

        sample_fmt = ctx.codec.audio_formats[-1].name
        sample_rate = 48000
        channel_layout = "stereo"
        channels = 2

        ctx.time_base = Fraction(1) / sample_rate
        ctx.sample_rate = sample_rate
        ctx.format = sample_fmt
        ctx.layout = channel_layout
        ctx.channels = channels

        ctx.open()

        resampler = AudioResampler(sample_fmt, channel_layout, sample_rate)

        container = av.open(fate_suite("audio-reference/chorusnoise_2ch_44kHz_s16.wav"))
        audio_stream = container.streams.audio[0]

        path = self.sandboxed("encoder.%s" % codec_name)

        samples = 0
        packet_sizes = []

        with open(path, "wb") as f:
            for frame in iter_frames(container, audio_stream):

                resampled_frames = resampler.resample(frame)
                for resampled_frame in resampled_frames:
                    samples += resampled_frame.samples

                    for packet in ctx.encode(resampled_frame):
                        packet_sizes.append(packet.size)
                        f.write(packet)

            for packet in ctx.encode(None):
                packet_sizes.append(packet.size)
                f.write(packet)

        ctx = Codec(codec_name, "r").create()
        ctx.sample_rate = sample_rate
        ctx.format = sample_fmt
        ctx.layout = channel_layout
        ctx.channels = channels
        ctx.open()

        result_samples = 0

        # should have more asserts but not sure what to check
        # libav and ffmpeg give different results
        # so can really use checksums
        for frame in iter_raw_frames(path, packet_sizes, ctx):
            result_samples += frame.samples
            self.assertEqual(frame.rate, sample_rate)
            self.assertEqual(len(frame.layout.channels), channels)
