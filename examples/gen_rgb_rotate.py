from __future__ import division

import logging

import av
from av.video.frame import VideoFrame
import Image
from tests.common import sandboxed

logging.basicConfig(level=logging.DEBUG)
av.logging.set_level(av.logging.VERBOSE)


width = 160
height = 120
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
    image = Image.new('RGB', (width, height), 'green')
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

