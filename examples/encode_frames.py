import argparse
import os
import sys

import av
import cv2


arg_parser = argparse.ArgumentParser()
arg_parser.add_argument('-r', '--rate', default='24')
arg_parser.add_argument('-b', '--bitrate', type=int, default=8000000)
arg_parser.add_argument('-c', '--codec', default='mpeg4')
arg_parser.add_argument('inputs', nargs='+')
arg_parser.add_argument('output', nargs=1)
args = arg_parser.parse_args()


output = av.open(args.output[0], 'w')
stream = output.add_stream(args.codec, args.rate)
stream.bit_rate = args.bitrate

for i, path in enumerate(args.inputs):

    print os.path.basename(path)

    img = cv2.imread(path)

    if not i:
        stream.height = img.shape[0]
        stream.width = img.shape[1]

    frame = av.VideoFrame.from_ndarray(img)
    packet = stream.encode(frame)
    output.mux(packet)

output.close()
