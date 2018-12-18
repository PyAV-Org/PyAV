import os
from fractions import Fraction
from unittest import SkipTest

import av
from av import AudioResampler, AVError, Codec, Packet
from av.codec.codec import UnknownCodecError

from .common import TestCase, fate_suite


def iter_frames(container, stream):
    for packet in container.demux(stream):
        for frame in packet.decode():
            yield frame


def iter_raw_frames(path, packet_sizes, ctx):
    with open(path, 'rb') as f:
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
            except AVError as e:
                if e.errno != 541478725:  # EOF
                    raise
                break
            for frame in frames:
                yield frame
            if not frames:
                break


class TestCodecContext(TestCase):

    def test_skip_frame_default(self):
        ctx = Codec('png', 'w').create()
        self.assertEqual(ctx.skip_frame.name, 'DEFAULT')


class TestEncoding(TestCase):

    def test_encoding_png(self):
        self.image_sequence_encode('png')

    def test_encoding_mjpeg(self):
        self.image_sequence_encode('mjpeg')

    def test_encoding_tiff(self):
        self.image_sequence_encode('tiff')

    def image_sequence_encode(self, codec_name):

        try:
            codec = Codec(codec_name, 'w')
        except UnknownCodecError:
            raise SkipTest()

        container = av.open(fate_suite('h264/interlaced_crop.mp4'))
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

            path = self.sandboxed('%s/encoder.%04d.%s' % (
                codec_name,
                frame_count,
                codec_name if codec_name != 'mjpeg' else 'jpg',
            ))
            path_list.append(path)
            with open(path, 'wb') as f:
                f.write(new_packet)
            frame_count += 1
            if frame_count > 5:
                break

        ctx = av.Codec(codec_name, 'r').create()

        for path in path_list:
            with open(path, 'rb') as f:
                size = os.fstat(f.fileno()).st_size
                packet = Packet(size)
                size = f.readinto(packet)
                frame = ctx.decode(packet)[0]
                self.assertEqual(frame.width, width)
                self.assertEqual(frame.height, height)
                self.assertEqual(frame.format.name, pix_fmt)

    def test_encoding_h264(self):
        self.video_encoding('libx264', {'crf': '19'})

    def test_encoding_mpeg4(self):
        self.video_encoding('mpeg4')

    def test_encoding_mpeg1video(self):
        self.video_encoding('mpeg1video')

    def test_encoding_dvvideo(self):
        options = {'pix_fmt': 'yuv411p',
                   'width': 720,
                   'height': 480}
        self.video_encoding('dvvideo', options)

    def test_encoding_dnxhd(self):
        options = {'b': '90M',  # bitrate
                   'pix_fmt': 'yuv422p',
                   'width': 1920,
                   'height': 1080,
                   'time_base': '1001/30000',
                   'max_frames': 5}
        self.video_encoding('dnxhd', options)

    def video_encoding(self, codec_name, options={}):

        try:
            codec = Codec(codec_name, 'w')
        except UnknownCodecError:
            raise SkipTest()

        container = av.open(fate_suite('h264/interlaced_crop.mp4'))
        video_stream = container.streams.video[0]

        pix_fmt = options.pop('pix_fmt', 'yuv420p')
        width = options.pop('width', 640)
        height = options.pop('height', 480)
        max_frames = options.pop('max_frames', 50)
        time_base = options.pop('time_base', video_stream.codec_context.time_base)

        ctx = codec.create()
        ctx.width = width
        ctx.height = height
        ctx.time_base = time_base
        ctx.framerate = 1 / ctx.time_base
        ctx.pix_fmt = pix_fmt
        ctx.options = options  # TODO
        ctx.open()

        path = self.sandboxed('encoder.%s' % codec_name)
        packet_sizes = []
        frame_count = 0

        with open(path, 'wb') as f:

            for frame in iter_frames(container, video_stream):

                """
                bad_frame = frame.reformat(width, 100, pix_fmt)
                with self.assertRaises(ValueError):
                    ctx.encode(bad_frame)

                bad_frame = frame.reformat(100, height, pix_fmt)
                with self.assertRaises(ValueError):
                    ctx.encode(bad_frame)

                bad_frame = frame.reformat(width, height, "rgb24")
                with self.assertRaises(ValueError):
                    ctx.encode(bad_frame)
                """

                if frame:
                    frame_count += 1

                new_frame = frame.reformat(width, height, pix_fmt) if frame else None
                for packet in ctx.encode(new_frame):
                    packet_sizes.append(packet.size)
                    f.write(packet)

                if frame_count >= max_frames:
                    break

            for packet in ctx.encode(None):
                packet_sizes.append(packet.size)
                f.write(packet)

        dec_codec_name = codec_name
        if codec_name == 'libx264':
            dec_codec_name = 'h264'

        ctx = av.Codec(dec_codec_name, 'r').create()
        ctx.open()

        decoded_frame_count = 0
        for frame in iter_raw_frames(path, packet_sizes, ctx):
            decoded_frame_count += 1
            self.assertEqual(frame.width, width)
            self.assertEqual(frame.height, height)
            self.assertEqual(frame.format.name, pix_fmt)

        self.assertEqual(frame_count, decoded_frame_count)

    def test_encoding_pcm_s24le(self):
        self.audio_encoding('pcm_s24le')

    def test_encoding_aac(self):
        self.audio_encoding('aac')

    def test_encoding_mp2(self):
        self.audio_encoding('mp2')

    def audio_encoding(self, codec_name):

        try:
            codec = Codec(codec_name, 'w')
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

        container = av.open(fate_suite('audio-reference/chorusnoise_2ch_44kHz_s16.wav'))
        audio_stream = container.streams.audio[0]

        path = self.sandboxed('encoder.%s' % codec_name)

        samples = 0
        packet_sizes = []

        with open(path, 'wb') as f:
            for frame in iter_frames(container, audio_stream):

                # We need to let the encoder retime.
                frame.pts = None

                """
                bad_resampler = AudioResampler(sample_fmt, "mono", sample_rate)
                bad_frame = bad_resampler.resample(frame)
                with self.assertRaises(ValueError):
                    next(encoder.encode(bad_frame))

                bad_resampler = AudioResampler(sample_fmt, channel_layout, 3000)
                bad_frame = bad_resampler.resample(frame)

                with self.assertRaises(ValueError):
                    next(encoder.encode(bad_frame))

                bad_resampler = AudioResampler('u8', channel_layout, 3000)
                bad_frame = bad_resampler.resample(frame)

                with self.assertRaises(ValueError):
                    next(encoder.encode(bad_frame))
                """

                resampled_frame = resampler.resample(frame)
                samples += resampled_frame.samples

                for packet in ctx.encode(resampled_frame):
                    # bytearray because python can
                    # freaks out if the first byte is NULL
                    f.write(bytearray(packet))
                    packet_sizes.append(packet.size)

            for packet in ctx.encode(None):
                packet_sizes.append(packet.size)
                f.write(bytearray(packet))

        ctx = Codec(codec_name, 'r').create()
        ctx.time_base = Fraction(1) / sample_rate
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
