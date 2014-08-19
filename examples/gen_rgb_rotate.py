from __future__ import division

import math

import av
from av.video.frame import VideoFrame
from PIL import Image
from tests.common import sandboxed


width = 320
height = 240
duration = 96

path = sandboxed('rgb_rotate.mov')
output = av.open(path, 'w')


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

