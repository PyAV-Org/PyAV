"""

As you can see, the subtitle API needs some work.

"""

import os
import sys
import pprint

import Image

from av import open


if not os.path.exists('subtitles'):
    os.makedirs('subtitles')

    
video = open(sys.argv[1])

streams = [s for s in video.streams if s.type == b'subtitle']
if not streams:
    print 'no subtitles'
    exit(1)

count = 0
for packet in video.demux([streams[0]]):
    
    for subtitle in packet.decode():
        
        for rect in subtitle.rects:
            if rect.type == 'ass':
                print rect.ass.rstrip('\n')
            if rect.type == 'bitmap':
                print rect.width, rect.height, rect.pict_buffers
                buffers = [b for b in rect.pict_buffers if b is not None]
                if buffers:
                    imgs = [
                        Image.frombuffer('L', (rect.width, rect.height), buffer, "raw", "L", 0, 1)
                        for buffer in buffers
                    ]
                    if len(imgs) == 1:
                        img = imgs[0]
                    elif len(imgs) == 2:
                        img = Image.merge('LA', imgs)
                    else:
                        img = Image.merge('RGBA', imgs)
                    img.save('subtitles/%04d.png' % count)
    
            count += 1
            if count > 10:
                pass
                # exit()
    
