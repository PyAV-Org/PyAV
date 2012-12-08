import os
import sys
import pprint

import Image

from av import open


frames = 512
per_bucket = 5

filmstrip = None
bucket = []

video = open(sys.argv[1])

streams = [s for s in video.streams if s.type == b'video']
streams = [streams[0]]

bucket_count = 0
for packet in video.demux(streams):
    
    frame = packet.decode()
    if not frame:
        continue
    
    if filmstrip is None:
        filmstrip = Image.new("RGBA", (frames, frame.height))
    
    img = Image.frombuffer("RGBA", (frame.width, frame.height), frame, "raw", "RGBA", 0, 1)
    img = img.resize((1, frame.height), Image.ANTIALIAS)
    bucket.append(img)
    
    if len(bucket) != per_bucket:
        continue
    
    bucket_count += 1
    print bucket_count
    
    img = bucket[0]
    for i, overlay in enumerate(bucket[1:]):
        img = Image.blend(img, overlay, 1.0 / (i + 2))
    bucket = []
    
    filmstrip.paste(img, (bucket_count - 1, 0))
    
    if bucket_count > frames:
        break

filmstrip.save('sandbox/%s.jpg' % os.path.basename(sys.argv[1]))