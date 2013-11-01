import os
import sys
import pprint

import Image

from av import open


video = open(sys.argv[1])
stream = next(s for s in video.streams if s.type == b'video')

frame_count = 0

for packet in video.demux(stream):
    for frame in packet.decode():

        frame_count += 1
        img = Image.frombuffer("RGB", (frame.width, frame.height), frame.to_rgb(), "raw", "RGB", 0, 1)
        img.save('sandbox/%04d.jpg' % frame_count)

    if frame_count > 5:
        break
