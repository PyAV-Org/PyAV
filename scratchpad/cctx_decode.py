from __future__ import print_function
import logging

logging.basicConfig()


import av
from av.codec import CodecContext, CodecParser
from av.video import VideoFrame
from av.packet import Packet


cc = CodecContext.create('mpeg4', 'r')
print(cc)


fh = open('test.mp4', 'r')

frame_count = 0

while True:

    chunk = fh.read(819200)
    for packet in cc.parse(chunk or None, allow_stream=True):
        print(packet)
        for frame in cc.decode(packet) or ():
            print(frame)
            img = frame.to_image()
            img.save('sandbox/test.%04d.jpg' % frame_count)
            frame_count += 1

    if not chunk:
        break # EOF!
