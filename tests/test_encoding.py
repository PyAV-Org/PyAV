from __future__ import division

import math
from .common import *
from av.video.stream import VideoStream


class TestBasicVideoEncoding(TestCase):

    def test_rgb_rotate(self):

        width = 320
        height = 240
        duration = 48

        path = self.sandboxed('rgb_rotate.mov')

        output = av.open(path, 'w')
        output.metadata['title'] = 'container'
        output.metadata['key'] = 'value'

        stream = output.add_stream("mpeg4", 24)
        stream.width = width
        stream.height = height
        stream.pix_fmt = "yuv420p"

        for frame_i in xrange(duration):

            frame = VideoFrame(width, height, 'rgb24')
            image = Image.new('RGB', (width, height), (
                int(255 * (0.5 + 0.5 * math.sin(frame_i / duration * 2 * math.pi))),
                int(255 * (0.5 + 0.5 * math.sin(frame_i / duration * 2 * math.pi + 2 / 3 * math.pi))),
                int(255 * (0.5 + 0.5 * math.sin(frame_i / duration * 2 * math.pi + 4 / 3 * math.pi))),
            ))
            frame.planes[0].update_from_string(image.tostring())

            packet = stream.encode(frame)
            if packet:
                output.mux(packet)

        while True:
            packet = stream.encode()
            if packet:
                output.mux(packet)
            else:
                break

        # Done!
        output.close()


        # Now inspect it a little.
        input_ = av.open(path)
        self.assertEqual(input_.name, path)
        self.assertEqual(len(input_.streams), 1)
        self.assertEqual(input_.metadata.get('title'), 'container', input_.metadata)
        self.assertEqual(input_.metadata.get('key'), None)
        stream = input_.streams[0]
        self.assertIsInstance(stream, VideoStream)
        self.assertEqual(stream.type, 'video')
        self.assertEqual(stream.name, 'mpeg4')
        self.assertEqual(stream.guessed_rate, 24)
        self.assertEqual(stream.average_rate, 24) # Only because we constructed is precisely.
        self.assertEqual(stream.rate, Fraction(1, 24))
        self.assertEqual(stream.time_base * stream.duration, 2)
        self.assertEqual(stream.format.name, 'yuv420p')
        self.assertEqual(stream.format.width, width)
        self.assertEqual(stream.format.height, height)


