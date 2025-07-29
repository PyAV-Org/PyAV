from fractions import Fraction

import av

from .common import TestCase, fate_suite


class TestAudioFifo(TestCase):
    def test_data(self) -> None:
        container = av.open(fate_suite("audio-reference/chorusnoise_2ch_44kHz_s16.wav"))
        stream = container.streams.audio[0]

        fifo = av.AudioFifo()

        input_ = []
        output = []

        for i, frame in enumerate(container.decode(stream)):
            input_.append(bytes(frame.planes[0]))
            fifo.write(frame)
            for frame in fifo.read_many(512, partial=i == 10):
                output.append(bytes(frame.planes[0]))
            if i == 10:
                break

        input_bytes = b"".join(input_)
        output_bytes = b"".join(output)
        min_len = min(len(input_bytes), len(output_bytes))

        assert min_len > 10 * 512 * 2 * 2
        assert input_bytes[:min_len] == output_bytes[:min_len]

    def test_pts_simple(self) -> None:
        fifo = av.AudioFifo()

        assert str(fifo).startswith(
            "<av.AudioFifo uninitialized, use fifo.write(frame), at 0x"
        )

        iframe = av.AudioFrame(samples=1024)
        iframe.pts = 0
        iframe.sample_rate = 48000
        iframe.time_base = Fraction("1/48000")

        fifo.write(iframe)

        assert str(fifo).startswith(
            "<av.AudioFifo 1024 samples of 48000hz <av.AudioLayout 'stereo'> <av.AudioFormat s16> at 0x"
        )

        oframe = fifo.read(512)
        assert oframe is not None
        assert oframe.pts == 0
        assert oframe.time_base == iframe.time_base

        assert fifo.samples_written == 1024
        assert fifo.samples_read == 512
        assert fifo.pts_per_sample == 1.0

        iframe.pts = 1024
        fifo.write(iframe)
        oframe = fifo.read(512)
        assert oframe is not None

        assert oframe.pts == 512
        assert oframe.time_base == iframe.time_base

        iframe.pts = 9999  # Wrong!
        self.assertRaises(ValueError, fifo.write, iframe)

    def test_pts_complex(self) -> None:
        fifo = av.AudioFifo()

        iframe = av.AudioFrame(samples=1024)
        iframe.pts = 0
        iframe.sample_rate = 48000
        iframe.time_base = Fraction("1/96000")

        fifo.write(iframe)
        iframe.pts = 2048
        fifo.write(iframe)

        oframe = fifo.read_many(1024)[-1]

        assert oframe.pts == 2048
        assert fifo.pts_per_sample == 2.0

    def test_missing_sample_rate(self) -> None:
        fifo = av.AudioFifo()

        iframe = av.AudioFrame(samples=1024)
        iframe.pts = 0
        iframe.time_base = Fraction("1/48000")

        fifo.write(iframe)

        oframe = fifo.read(512)

        assert oframe is not None
        assert oframe.pts is None
        assert oframe.sample_rate == 0
        assert oframe.time_base == iframe.time_base

    def test_missing_time_base(self) -> None:
        fifo = av.AudioFifo()

        iframe = av.AudioFrame(samples=1024)
        iframe.pts = 0
        iframe.sample_rate = 48000

        fifo.write(iframe)

        oframe = fifo.read(512)

        assert oframe is not None
        assert oframe.pts is None and oframe.time_base is None
        assert oframe.sample_rate == iframe.sample_rate
