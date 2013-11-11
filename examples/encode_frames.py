import argparse
import os
import sys

import av
import cv2


arg_parser = argparse.ArgumentParser()
arg_parser.add_argument('-r', '--rate', default='23.976')
arg_parser.add_argument('-f', '--format', default='yuv420p')
arg_parser.add_argument('-w', '--width', type=int)
arg_parser.add_argument('--height', type=int)
arg_parser.add_argument('-b', '--bitrate', type=int, default=8000000)
arg_parser.add_argument('-c', '--codec', default='mpeg4')
arg_parser.add_argument('inputs', nargs='+')
arg_parser.add_argument('output', nargs=1)
args = arg_parser.parse_args()


output = av.open(args.output[0], 'w')
stream = output.add_stream(args.codec, args.rate)
stream.bit_rate = args.bitrate
stream.pix_fmt = args.format

for i, path in enumerate(args.inputs):

    print os.path.basename(path)

    img = cv2.imread(path)

    if not i:
        stream.height = args.height or (args.width * img.shape[0] / img.shape[1]) or img.shape[0]
        stream.width = args.width or img.shape[1]

    frame = av.VideoFrame.from_ndarray(img, format='bgr24')
    packet = stream.encode(frame)
    output.mux(packet)

output.close()
