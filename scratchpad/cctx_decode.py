import logging

logging.basicConfig()


import av
from av.codeccontext import CodecContext
from av.video import VideoFrame
from av.packet import Packet


cc = CodecContext.create('mpeg4', 'r')
print cc

fh = open('test.mp4', 'r')

frame_count = 0

while True:
    chunk = fh.read(100)
    if not chunk:
        break

    packet = Packet(chunk)
    print packet
    assert str(buffer(packet)) == chunk

    frames = cc.decode(packet) or ()
    for frame in frames:
        print frame
        img = frame.to_image()
        img.save('sandbox/test.%04d.jpg' % frame_count)
        frame_count += 1



