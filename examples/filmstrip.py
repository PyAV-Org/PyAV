import os
import sys
import pprint

import Image

from av import open


filmstrip = None

video = open(sys.argv[1])


def frame_iter(video):
    streams = [s for s in video.streams if s.type == b'video']
    streams = [streams[0]]
    for packet in video.demux(streams):
        frame = packet.decode()
        if frame:
            yield frame

for frame_i, frame in enumerate(frame_iter(video)):

    if filmstrip is None:
        filmstrip = Image.new("RGBA", (512, frame.height))

    # Double the width.
    if frame_i >= filmstrip.size[0]:
        filmstrip = filmstrip.crop((0, 0, filmstrip.size[0] * 2, filmstrip.size[1]))
        print 'Resized to', filmstrip.size[0]
    
    img = Image.frombuffer("RGBA", (frame.width, frame.height), frame, "raw", "RGBA", 0, 1)
    img = img.resize((1, frame.height), Image.ANTIALIAS)
    
    filmstrip.paste(img, (frame_i, 0))


filmstrip = filmstrip.crop((0, 0, frame_i + 1, filmstrip.size[1]))
filmstrip.save('sandbox/%s.jpg' % os.path.basename(sys.argv[1]), quality=90)