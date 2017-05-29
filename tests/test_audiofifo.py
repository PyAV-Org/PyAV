from __future__ import print_function
from .common import *


class TestAudioFifo(TestCase):

    def test_1khz(self):

        container = av.open(fate_suite('audio-reference/chorusnoise_2ch_44kHz_s16.wav'))
        stream = container.streams.audio[0]

        fifo = av.AudioFifo()

        input_ = []
        output = []

        for i, packet in enumerate(container.demux(stream)):
            for frame in packet.decode():
                
                print('<<<', frame)
                
                input_.append(frame.planes[0].to_bytes())
                fifo.write(frame)
                while frame:
                    frame = fifo.read(512)
                    if frame:
                        print('>>>', frame)
                        output.append(frame.planes[0].to_bytes())

            if len(output) > 10:
                break

        input_ = b''.join(input_)
        output = b''.join(output)
        min_len = min(len(input_), len(output))

        self.assertTrue(min_len > 10 * 512 * 2 * 2)
        self.assertTrue(input_[:min_len] == output[:min_len])

    def test_pts_simple(self):

        fifo = av.AudioFifo()

        iframe = av.AudioFrame(samples=1024)
        iframe.pts = 0
        # iframe.sample_rate = 48000
        iframe.time_base = '1/48000'

        fifo.write(iframe)

        oframe = fifo.read(1024)
        self.assertTrue(oframe is not None)
        self.assertEqual(oframe.pts, iframe.pts)
        self.assertEqual(oframe.time_base, iframe.time_base)
        
