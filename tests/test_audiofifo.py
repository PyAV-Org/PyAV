import av

from .common import TestCase, fate_suite


class TestAudioFifo(TestCase):
    def test_data(self):
        container = av.open(fate_suite("audio-reference/chorusnoise_2ch_44kHz_s16.wav"))
        stream = container.streams.audio[0]

        fifo = av.AudioFifo()

        input_ = []
        output = []

        for i, packet in enumerate(container.demux(stream)):
            for frame in packet.decode():
                input_.append(bytes(frame.planes[0]))
                fifo.write(frame)
                for frame in fifo.read_many(512, partial=i == 10):
                    output.append(bytes(frame.planes[0]))
            if i == 10:
                break

        input_ = b"".join(input_)
        output = b"".join(output)
        min_len = min(len(input_), len(output))

        self.assertTrue(min_len > 10 * 512 * 2 * 2)
        self.assertTrue(input_[:min_len] == output[:min_len])

    def test_pts_simple(self):
        fifo = av.AudioFifo()

        # ensure __repr__ does not crash
        self.assertTrue(
            str(fifo).startswith(
                "<av.AudioFifo uninitialized, use fifo.write(frame), at 0x"
            )
        )

        iframe = av.AudioFrame(samples=1024)
        iframe.pts = 0
        iframe.sample_rate = 48000
        iframe.time_base = "1/48000"

        fifo.write(iframe)

        # ensure __repr__ was updated
        self.assertTrue(
            str(fifo).startswith(
                "<av.AudioFifo 1024 samples of 48000hz <av.AudioLayout 'stereo'> <av.AudioFormat s16> at 0x"
            )
        )

        oframe = fifo.read(512)
        self.assertTrue(oframe is not None)
        self.assertEqual(oframe.pts, 0)
        self.assertEqual(oframe.time_base, iframe.time_base)

        self.assertEqual(fifo.samples_written, 1024)
        self.assertEqual(fifo.samples_read, 512)
        self.assertEqual(fifo.pts_per_sample, 1.0)

        iframe.pts = 1024
        fifo.write(iframe)
        oframe = fifo.read(512)
        self.assertTrue(oframe is not None)
        self.assertEqual(oframe.pts, 512)
        self.assertEqual(oframe.time_base, iframe.time_base)

        iframe.pts = 9999  # Wrong!
        self.assertRaises(ValueError, fifo.write, iframe)

    def test_pts_complex(self):
        fifo = av.AudioFifo()

        iframe = av.AudioFrame(samples=1024)
        iframe.pts = 0
        iframe.sample_rate = 48000
        iframe.time_base = "1/96000"

        fifo.write(iframe)
        iframe.pts = 2048
        fifo.write(iframe)

        oframe = fifo.read_many(1024)[-1]

        self.assertEqual(oframe.pts, 2048)
        self.assertEqual(fifo.pts_per_sample, 2.0)

    def test_missing_sample_rate(self):
        fifo = av.AudioFifo()

        iframe = av.AudioFrame(samples=1024)
        iframe.pts = 0
        iframe.time_base = "1/48000"

        fifo.write(iframe)

        oframe = fifo.read(512)

        self.assertTrue(oframe is not None)
        self.assertIsNone(oframe.pts)
        self.assertEqual(oframe.sample_rate, 0)
        self.assertEqual(oframe.time_base, iframe.time_base)

    def test_missing_time_base(self):
        fifo = av.AudioFifo()

        iframe = av.AudioFrame(samples=1024)
        iframe.pts = 0
        iframe.sample_rate = 48000

        fifo.write(iframe)

        oframe = fifo.read(512)

        self.assertTrue(oframe is not None)
        self.assertIsNone(oframe.pts)
        self.assertIsNone(oframe.time_base)
        self.assertEqual(oframe.sample_rate, iframe.sample_rate)
