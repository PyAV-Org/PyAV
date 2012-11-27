import sys
import pprint

from av import open


video = open(sys.argv[1])

streams = [s for s in video.streams if s.type == b'subtitle']
if not streams:
    print 'no subtitles'
    exit(1)

for i, packet in enumerate(video.demux([streams[0]])):
    
    subtitle = packet.decode()
    for rect in subtitle.rects:
        if rect.type == 'ass':
            print rect.ass.rstrip('\n')
