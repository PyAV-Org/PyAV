from .common import *
import av
from fractions import Fraction
from av.buffer import Buffer
from av.packet import Packet
from av.audio.resampler import AudioResampler

def iter_frames(container, stream):
    for packet in container.demux(stream):
        for frame in packet.decode():
            yield frame

def iter_raw_frames(path, packet_sizes, decoder):
    with open(path, 'rb') as f:
        for size in packet_sizes:
            packet = Packet(size)
            read_size = f.readinto(packet)
            if not read_size:
                break
            for frame in decoder.decode(packet):
                yield frame

        for frame in decoder.flush():
            yield frame

class TestCoders(TestCase):

    def test_encoding_png(self):
        self.image_sequence_encode('png')

    def test_encoding_mjpeg(self):
        self.image_sequence_encode('mjpeg')

    def test_encoding_tiff(self):
        self.image_sequence_encode('tiff')

    def image_sequence_encode(self, codec):

        if not codec in av.codec.codecs_availible:
            raise SkipTest()

        container = av.open(fate_suite('h264/interlaced_crop.mp4'))
        video_stream = next(s for s in container.streams if s.type == 'video')

        width =  640
        height = 480

        encoder = av.Encoder(codec)

        pix_fmt = encoder.codec.video_formats[0].name

        encoder.width = width
        encoder.height = height
        encoder.time_base = Fraction(24000, 1001)
        encoder.pix_fmt = pix_fmt
        encoder.open()

        frame_count = 1
        path_list = []
        for frame in iter_frames(container, video_stream):
            new_frame = frame.reformat(width, height, pix_fmt)
            for i, new_packet in enumerate(encoder.encode(new_frame)):
                path = self.sandboxed('%s/encoder.%04d.%s' % (codec,
                                                              frame_count,
                                                              codec if codec != 'mjpeg' else 'jpg'))
                path_list.append(path)
                with open(path, 'wb') as f:
                    f.write(new_packet)
                frame_count += 1
            if frame_count > 5:
                break

        decoder = av.Decoder(codec)
        decoder.open()

        for path in path_list:
            with open(path, 'rb') as f:
                size = os.fstat(f.fileno()).st_size
                packet = Packet(size)
                size = f.readinto(packet)
                frame = next(decoder.decode(packet))
                self.assertEqual(frame.width, width)
                self.assertEqual(frame.height, height)
                self.assertEqual(frame.format.name, pix_fmt)

    def test_encoding_h264(self):
        self.video_encoding('libx264', {'crf':'19'})

    def test_encoding_mpeg4(self):
        self.video_encoding('mpeg4')

    def test_encoding_mpeg1video(self):
        self.video_encoding('mpeg1video')

    def test_encoding_dvvideo(self):
        options = {'pix_fmt':'yuv411p',
                   'width':720,
                   'height':480}
        self.video_encoding('dvvideo', options)

    def test_encoding_dnxhd(self):
        options = {'b':'90M', #bitrate
                   'pix_fmt':'yuv422p',
                   'width':  1920,
                   'height': 1080,
                   'time_base': Fraction(30000, 1001),
                   'max_frames': 5}
        self.video_encoding('dnxhd', options)

    def video_encoding(self, codec, options = {}):

        if not codec in av.codec.codecs_availible:
            raise SkipTest()

        container = av.open(fate_suite('h264/interlaced_crop.mp4'))
        video_stream = next(s for s in container.streams if s.type == 'video')

        pix_fmt = options.get('pix_fmt', 'yuv420p')
        width =  options.get('width', 640)
        height = options.get('height', 480)

        max_frames = options.get('max_frames', 1000)
        time_base = options.get('time_base', Fraction(24000, 1001))

        for key in ('pix_fmt', 'width', 'height', 'max_frames', 'time_base'):
            if key in options:
                del options[key]

        encoder = av.Encoder(codec)
        encoder.width = width
        encoder.height = height
        encoder.time_base = time_base
        encoder.pix_fmt = pix_fmt
        encoder.options = options
        encoder.open()

        path = self.sandboxed('encoder.%s' % codec)
        packet_sizes = []
        frame_count = 0
        test_bad = True
        with open(path, 'wb') as f:
            for frame in iter_frames(container, video_stream):

                if frame_count > max_frames:
                    break

                if test_bad:
                    bad_frame = frame.reformat(width, 100, pix_fmt)
                    with self.assertRaises(ValueError):
                        next(encoder.encode(bad_frame))

                    bad_frame = frame.reformat(100, height, pix_fmt)
                    with self.assertRaises(ValueError):
                        next(encoder.encode(bad_frame))

                    bad_frame = frame.reformat(width, height, "rgb24")
                    with self.assertRaises(ValueError):
                        next(encoder.encode(bad_frame))
                    test_bad = False

                new_frame = frame.reformat(width, height, pix_fmt)
                for new_packet in encoder.encode(new_frame):
                    packet_sizes.append(new_packet.size)
                    f.write(new_packet)
                frame_count += 1

            for new_packet in encoder.flush():
                packet_sizes.append(new_packet.size)
                f.write(new_packet)

        dec_codec = codec
        if codec == 'libx264':
            dec_codec = 'h264'

        decoder = av.Decoder(dec_codec)
        decoder.open()

        decoded_frame_count = 0
        for frame in iter_raw_frames(path, packet_sizes, decoder):
            decoded_frame_count += 1
            self.assertEqual(frame.width, width)
            self.assertEqual(frame.height, height)
            self.assertEqual(frame.format.name, pix_fmt)

        self.assertEqual(decoded_frame_count, frame_count)

    def test_encoding_pcm_s24le(self):
        self.audio_encoding('pcm_s24le')

    def test_encoding_aac(self):
        self.audio_encoding('aac')

    def test_encoding_mp2(self):
        self.audio_encoding('mp2')

    def audio_encoding(self, codec):

        if not codec in av.codec.codecs_availible:
            raise SkipTest()

        encoder = av.Encoder(codec)
        if encoder.codec.experimental:
            raise SkipTest()

        sample_fmt  = encoder.codec.audio_formats[-1].name

        sample_rate = 48000
        channel_layout = "stereo"
        channels = 2
        encoder.time_base = sample_rate
        encoder.sample_rate = sample_rate
        encoder.sample_fmt = sample_fmt
        encoder.channels = channels
        encoder.open()

        resampler = AudioResampler(sample_fmt, channel_layout, sample_rate)

        container = av.open(fate_suite('audio-reference/chorusnoise_2ch_44kHz_s16.wav'))
        audio_stream = next(s for s in container.streams if s.type == 'audio')
        path = self.sandboxed('encoder.%s' % codec)

        samples = 0
        packet_sizes = []

        test_bad = True

        with open(path, 'w') as f:
            for frame in iter_frames(container, audio_stream):

                if test_bad:
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

                    test_bad = False

                resampled_frame = resampler.resample(frame)
                samples += resampled_frame.samples
                for new_packet in encoder.encode(resampled_frame):
                    # bytearray because python can
                    # freaks out if the first byte is NULL
                    f.write(bytearray(new_packet))
                    packet_sizes.append(new_packet.size)

            for new_packet in encoder.flush():
                packet_sizes.append(new_packet.size)
                f.write(bytearray(new_packet))

        decoder = av.Decoder(codec)
        decoder.time_base = sample_rate
        decoder.sample_rate = sample_rate
        decoder.sample_fmt = sample_fmt
        decoder.channels = channels
        decoder.open()

        result_samples = 0

        # should have more asserts but not sure what to check
        # libav and ffmpeg give different results
        # so can really use checksums
        for frame in iter_raw_frames(path, packet_sizes, decoder):
            result_samples += frame.samples
            self.assertEqual(frame.rate, sample_rate)
            self.assertEqual(len(frame.layout.channels), channels)

# import logging
# logging.basicConfig()
