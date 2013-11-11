import os
import sys
import pprint

import Image

from av import open


video = open(sys.argv[1])
stream = next(s for s in video.streams if s.type == b'video')

for packet in video.demux(stream):
    for frame in packet.decode():
        frame.to_image().save('sandbox/%04d.jpg' % frame.index)

    if frame_count > 5:
        break
