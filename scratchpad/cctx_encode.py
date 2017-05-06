import logging

from PIL import Image, ImageFont, ImageDraw

logging.basicConfig()

import av
from av.codec import CodecContext
from av.video import VideoFrame

from tests.common import fate_suite


cc = CodecContext.create('flv', 'w')
print cc

base_img = Image.open(fate_suite('png1/lena-rgb24.png'))
font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 15)



fh = open('test.flv', 'w')

for i in range(30):

    print i
    img = base_img.copy()
    draw = ImageDraw.Draw(img)
    draw.text((10, 10), "FRAME %02d" % i, font=font)

    frame = VideoFrame.from_image(img)
    frame = frame.reformat(format='yuv420p')
    print '   ', frame

    packet = cc.encode(frame)
    print '   ', packet

    fh.write(str(buffer(packet)))

print 'Flushing...'

while True:
    packet = cc.encode()
    if not packet:
        break
    print '   ', packet
    fh.write(str(buffer(packet)))

print 'Done!'
