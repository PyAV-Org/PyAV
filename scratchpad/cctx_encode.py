import logging

logging.basicConfig()


import av
from av.codeccontext import CodecContext
from av.video import VideoFrame
from PIL import Image, ImageFont, ImageDraw


cc = CodecContext.create('mpeg4', 'w')
print cc

base_img = Image.open('tests/assets/lenna.png')
font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 15)



fh = open('test.mp4', 'w')

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
