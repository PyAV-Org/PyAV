from __future__ import division

import math

import av
from av.video.frame import VideoFrame
import Image
from tests.common import sandboxed


width = 320
height = 240
duration = 96

path = sandboxed('rgb_rotate.mov')
output = av.open(path, 'w')

stream = output.add_stream("h264", 24)
codec = stream.codec
    
# set output size
codec.width = width
codec.height = height
# codec.bit_rate = 256000
codec.pix_fmt = "yuv420p"
    
# Start?
output.dump()

for frame_i in xrange(duration):

    # Magic goes here.
    frame = VideoFrame(width, height, 'rgb24')

    image = Image.new('RGB', (width, height), (
        int(255 * (0.5 + 0.5 * math.sin(frame_i / duration * 2 * math.pi))),
        int(255 * (0.5 + 0.5 * math.sin(frame_i / duration * 2 * math.pi + 2 / 3 * math.pi))),
        int(255 * (0.5 + 0.5 * math.sin(frame_i / duration * 2 * math.pi + 4 / 3 * math.pi))),
    ))
    frame.update_from_string(image.tostring())

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

