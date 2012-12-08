import os
import sys
import pprint

import Image

from av import open


video = open(sys.argv[1])

streams = [s for s in video.streams if s.type == b'video']
streams = [streams[0]]

frame_count = 0
for packet in video.demux(streams):
    
    if frame_count > 5:
        break

    frame = packet.decode()
    if not frame:
        continue
    frame_count += 1
    
    img = Image.frombuffer("RGBA", (frame.width, frame.height), frame, "raw", "RGBA", 0, 1)
    img.save('sandbox/%04d.jpg' % frame_count)
    