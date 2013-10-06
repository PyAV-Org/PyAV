"""
randomly save out frames of video
"""

import os
import sys
import random
import Image

from av import open
from av.seek import SeekContext

video = open(sys.argv[1])

streams = [s for s in video.streams if s.type == b'video']
streams = [streams[0]]

stream = streams[0]


frame_count = 0


seek = SeekContext(video,stream)


frames = len(seek) 

print "frames =", frames
shuff = range(10)
random.shuffle(shuff)

for i,x in enumerate(shuff):

    frame = seek[x]

    frame_nb = frame.frame_index
    
    path = 'sandbox/%s.%08d.jpg' % ("seek", frame_nb)
    
    assert x == frame_nb
    
    print i,frames, frame_nb, path
    img = Image.frombuffer("RGBA", (frame.width, frame.height), frame.to_rgba(), "raw", "RGBA", 0, 1)
    img.save(path)


