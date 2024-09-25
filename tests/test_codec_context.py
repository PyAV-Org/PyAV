from __future__ import annotations

import os
from fractions import Fraction
from typing import Iterator, TypedDict, overload

import pytest

import av
from av import (
    AudioCodecContext,
    AudioFrame,
    AudioLayout,
    AudioResampler,
    Codec,
    Packet,
    VideoCodecContext,
    VideoFrame,
)
from av.codec.codec import UnknownCodecError
from av.video.frame import PictureType

from .common import TestCase, fate_suite


class Options(TypedDict, total=False):
    b: str
    crf: str
    pix_fmt: str
    width: int
    height: int
    max_frames: int
    time_base: Fraction
    gop_size: int


@overload
def iter_raw_frames(
    path: str, packet_sizes: list[int], ctx: VideoCodecContext
) -> Iterator[VideoFrame]: ...
@overload
def iter_raw_frames(
    path: str, packet_sizes: list[int], ctx: AudioCodecContext
) -> Iterator[AudioFrame]: ...
def iter_raw_frames(
    path: str, packet_sizes: list[int], ctx: VideoCodecContext | AudioCodecContext
) -> Iterator[VideoFrame | AudioFrame]:
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
        assert ctx.skip_frame.name == "DEFAULT"

    def test_codec_delay(self) -> None:
        with av.open(fate_suite("mkv/codec_delay_opus.mkv")) as container:
            assert container.streams.audio[0].codec_context.delay == 312
        with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
            assert container.streams.video[0].codec_context.delay == 0

    def test_codec_tag(self):
        ctx = Codec("mpeg4", "w").create()
        assert ctx.codec_tag == "\x00\x00\x00\x00"
        ctx.codec_tag = "xvid"
        assert ctx.codec_tag == "xvid"

        # wrong length
        with pytest.raises(
            ValueError, match="Codec tag should be a 4 character string"
        ):
            ctx.codec_tag = "bob"

        # wrong type
        with pytest.raises(
            ValueError, match="Codec tag should be a 4 character string"
        ):
            ctx.codec_tag = 123

        with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
            assert container.streams[0].codec_tag == "avc1"

    def test_decoder_extradata(self):
        ctx = av.codec.Codec("h264", "r").create()
        assert ctx.extradata is None
        assert ctx.extradata_size == 0

        ctx.extradata = b"123"
        assert ctx.extradata == b"123"
        assert ctx.extradata_size == 3

        ctx.extradata = b"54321"
        assert ctx.extradata == b"54321"
        assert ctx.extradata_size == 5

        ctx.extradata = None
        assert ctx.extradata is None
        assert ctx.extradata_size == 0

    def test_decoder_gop_size(self) -> None:
        ctx = av.codec.Codec("h264", "r").create("video")

        with pytest.raises(RuntimeError):
            ctx.gop_size

    def test_decoder_timebase(self) -> None:
        ctx = av.codec.Codec("h264", "r").create()

        with pytest.raises(RuntimeError):
            ctx.time_base

        with pytest.raises(RuntimeError):
            ctx.time_base = Fraction(1, 25)

    def test_encoder_extradata(self) -> None:
        ctx = av.codec.Codec("h264", "w").create()
        assert ctx.extradata is None
        assert ctx.extradata_size == 0

        ctx.extradata = b"123"
        assert ctx.extradata == b"123"
        assert ctx.extradata_size == 3

    def test_encoder_pix_fmt(self) -> None:
        ctx = av.codec.Codec("h264", "w").create("video")

        # valid format
        ctx.pix_fmt = "yuv420p"
        assert ctx.pix_fmt == "yuv420p"

        # invalid format
        with self.assertRaises(ValueError) as cm:
            ctx.pix_fmt = "__unknown_pix_fmt"
        assert str(cm.exception) == "not a pixel format: '__unknown_pix_fmt'"
        assert ctx.pix_fmt == "yuv420p"

    def test_bits_per_coded_sample(self):
        with av.open(fate_suite("qtrle/aletrek-rle.mov")) as container:
            stream = container.streams.video[0]
            stream.bits_per_coded_sample = 32

            for packet in container.demux(stream):
                for frame in packet.decode():
                    pass
                assert isinstance(packet.stream, av.VideoStream)
                assert packet.stream.bits_per_coded_sample == 32

        with av.open(fate_suite("qtrle/aletrek-rle.mov")) as container:
            stream = container.streams.video[0]
            stream.bits_per_coded_sample = 31

            with pytest.raises(av.error.InvalidDataError):
                for _ in container.decode(stream):
                    pass

        with av.open(self.sandboxed("output.mov"), "w") as output:
            stream = output.add_stream("qtrle")

            with pytest.raises(ValueError):
                stream.codec_context.bits_per_coded_sample = 32

    def test_parse(self) -> None:
        # This one parses into a single packet.
        self._assert_parse("mpeg4", fate_suite("h264/interlaced_crop.mp4"))

        # This one parses into many small packets.
        self._assert_parse("mpeg2video", fate_suite("mpeg2/mpeg2_field_encoding.ts"))

    def _assert_parse(self, codec_name: str, path: str) -> None:
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
            assert len(parsed_source) == len(full_source)
            assert full_source == parsed_source


class TestEncoding(TestCase):
    def test_encoding_png(self) -> None:
        self.image_sequence_encode("png")

    def test_encoding_mjpeg(self) -> None:
        self.image_sequence_encode("mjpeg")

    def test_encoding_tiff(self) -> None:
        self.image_sequence_encode("tiff")

    def image_sequence_encode(self, codec_name: str) -> None:
        try:
            codec = Codec(codec_name, "w")
        except UnknownCodecError:
            pytest.skip(f"Unknown codec: {codec_name}")

        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        video_stream = container.streams.video[0]

        width = 640
        height = 480

        ctx = codec.create("video")

        assert ctx.codec.video_formats
        pix_fmt = ctx.codec.video_formats[0].name

        ctx.width = width
        ctx.height = height

        assert video_stream.time_base is not None
        ctx.time_base = video_stream.time_base
        ctx.pix_fmt = pix_fmt
        ctx.open()

        frame_count = 1
        path_list = []
        for frame in container.decode(video_stream):
            new_frame = frame.reformat(width, height, pix_fmt)
            new_packets = ctx.encode(new_frame)

            assert len(new_packets) == 1
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

        ctx = av.Codec(codec_name, "r").create("video")

        for path in path_list:
            with open(path, "rb") as f:
                size = os.fstat(f.fileno()).st_size
                packet = Packet(size)
                size = f.readinto(packet)
                frame = ctx.decode(packet)[0]
                assert frame.width == width
                assert frame.height == height
                assert frame.format.name == pix_fmt

    def test_encoding_h264(self) -> None:
        self.video_encoding("h264", {"crf": "19"})

    def test_encoding_mpeg4(self) -> None:
        self.video_encoding("mpeg4")

    def test_encoding_xvid(self) -> None:
        self.video_encoding("mpeg4", codec_tag="xvid")

    def test_encoding_mpeg1video(self) -> None:
        self.video_encoding("mpeg1video")

    def test_encoding_dvvideo(self) -> None:
        options: Options = {"pix_fmt": "yuv411p", "width": 720, "height": 480}
        self.video_encoding("dvvideo", options)

    def test_encoding_dnxhd(self) -> None:
        options: Options = {
            "b": "90M",  # bitrate
            "pix_fmt": "yuv422p",
            "width": 1920,
            "height": 1080,
            "time_base": Fraction(1001, 30_000),
            "max_frames": 5,
        }
        self.video_encoding("dnxhd", options)

    def video_encoding(
        self,
        codec_name: str,
        options: Options = {},
        codec_tag: str | None = None,
    ) -> None:
        try:
            codec = Codec(codec_name, "w")
        except UnknownCodecError:
            pytest.skip(f"Unknown codec: {codec_name}")

        container = av.open(fate_suite("h264/interlaced_crop.mp4"))
        video_stream = container.streams.video[0]

        assert video_stream.time_base is not None

        pix_fmt = options.pop("pix_fmt", "yuv420p")
        width = options.pop("width", 640)
        height = options.pop("height", 480)
        max_frames = options.pop("max_frames", 50)
        time_base = options.pop("time_base", video_stream.time_base)
        gop_size = options.pop("gop_size", 20)

        ctx = codec.create("video")
        ctx.width = width
        ctx.height = height
        ctx.time_base = time_base
        ctx.framerate = 1 / ctx.time_base
        ctx.pix_fmt = pix_fmt
        ctx.gop_size = gop_size
        ctx.options = options  # type: ignore
        if codec_tag:
            ctx.codec_tag = codec_tag
        ctx.open()

        path = self.sandboxed(f"encoder.{codec_name}")
        packet_sizes = []
        frame_count = 0

        with open(path, "wb") as f:
            for frame in container.decode(video_stream):
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

        ctx = av.Codec(dec_codec_name, "r").create("video")
        ctx.open()

        keyframe_indices = []
        decoded_frame_count = 0
        for frame in iter_raw_frames(path, packet_sizes, ctx):
            decoded_frame_count += 1
            assert frame.width == width
            assert frame.height == height
            assert frame.format.name == pix_fmt
            if frame.key_frame:
                keyframe_indices.append(decoded_frame_count)

        assert frame_count == decoded_frame_count

        assert isinstance(
            all(keyframe_index for keyframe_index in keyframe_indices), int
        )
        decoded_gop_sizes = [
            j - i for i, j in zip(keyframe_indices[:-1], keyframe_indices[1:])
        ]
        if codec_name in ("dvvideo", "dnxhd") and all(
            i == 1 for i in decoded_gop_sizes
        ):
            pytest.skip()
        for i in decoded_gop_sizes:
            assert i == gop_size

        final_gop_size = decoded_frame_count - max(keyframe_indices)
        assert final_gop_size < gop_size

    def test_encoding_pcm_s24le(self) -> None:
        self.audio_encoding("pcm_s24le")

    def test_encoding_aac(self) -> None:
        self.audio_encoding("aac")

    def test_encoding_mp2(self) -> None:
        self.audio_encoding("mp2")

    def audio_encoding(self, codec_name: str) -> None:
        self._audio_encoding(codec_name=codec_name, channel_layout="stereo")
        self._audio_encoding(
            codec_name=codec_name, channel_layout=AudioLayout("stereo")
        )

    def _audio_encoding(
        self, *, codec_name: str, channel_layout: str | AudioLayout
    ) -> None:
        try:
            codec = Codec(codec_name, "w")
        except UnknownCodecError:
            pytest.skip(f"Unknown codec: {codec_name}")

        ctx = codec.create(kind="audio")

        if ctx.codec.experimental:
            pytest.skip(f"Experimental codec: {codec_name}")

        assert ctx.codec.audio_formats
        sample_fmt = ctx.codec.audio_formats[-1].name
        sample_rate = 48000

        ctx.time_base = Fraction(1) / sample_rate
        ctx.sample_rate = sample_rate
        ctx.format = sample_fmt
        ctx.layout = channel_layout

        ctx.open()

        resampler = AudioResampler(sample_fmt, channel_layout, sample_rate)

        container = av.open(fate_suite("audio-reference/chorusnoise_2ch_44kHz_s16.wav"))
        audio_stream = container.streams.audio[0]

        path = self.sandboxed(f"encoder.{codec_name}")

        samples = 0
        packet_sizes = []

        with open(path, "wb") as f:
            for frame in container.decode(audio_stream):
                resampled_frames = resampler.resample(frame)
                for resampled_frame in resampled_frames:
                    assert resampled_frame.time_base == Fraction(1, 48000)
                    samples += resampled_frame.samples

                    for packet in ctx.encode(resampled_frame):
                        assert packet.time_base == Fraction(1, 48000)
                        packet_sizes.append(packet.size)
                        f.write(packet)

            for packet in ctx.encode(None):
                assert packet.time_base == Fraction(1, 48000)
                packet_sizes.append(packet.size)
                f.write(packet)

        ctx = Codec(codec_name, "r").create("audio")
        ctx.sample_rate = sample_rate
        ctx.format = sample_fmt
        ctx.layout = channel_layout
        ctx.open()

        result_samples = 0

        for frame in iter_raw_frames(path, packet_sizes, ctx):
            result_samples += frame.samples
            assert frame.sample_rate == sample_rate
            assert frame.layout.nb_channels == 2
