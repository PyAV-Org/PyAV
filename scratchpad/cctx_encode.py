import logging

from PIL import Image, ImageDraw, ImageFont

from av.codec import CodecContext
from av.video import VideoFrame
from tests.common import fate_suite


logging.basicConfig()


cc = CodecContext.create('flv', 'w')
print(cc)

base_img = Image.open(fate_suite('png1/lena-rgb24.png'))
font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 15)


fh = open('test.flv', 'wb')

for i in range(30):

    print(i)
    img = base_img.copy()
    draw = ImageDraw.Draw(img)
    draw.text((10, 10), "FRAME %02d" % i, font=font)

    frame = VideoFrame.from_image(img)
    frame = frame.reformat(format='yuv420p')
    print('   ', frame)

    packet = cc.encode(frame)
    print('   ', packet)

    fh.write(bytes(packet))

print('Flushing...')

while True:
    packet = cc.encode()
    if not packet:
        break
    print('   ', packet)
    fh.write(bytes(packet))

print('Done!')
