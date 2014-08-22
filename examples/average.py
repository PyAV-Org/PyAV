import argparse
import os
import sys
import pprint
import itertools

import cv2

from av import open


parser = argparse.ArgumentParser()
parser.add_argument('-f', '--format')
parser.add_argument('-n', '--frames', type=int, default=0)
parser.add_argument('path', nargs='+')
args = parser.parse_args()

max_size = 24 * 60 # One minute's worth.


def frame_iter(video):
    count = 0
    streams = [s for s in video.streams if s.type == b'video']
    streams = [streams[0]]
    for packet in video.demux(streams):
        for frame in packet.decode():
            yield frame
            count += 1
            if args.frames and count > args.frames:
                return


for src_path in args.path:

    print 'reading', src_path

    basename = os.path.splitext(os.path.basename(src_path))[0]
    dir_name = os.path.join('sandbox', basename)
    if not os.path.exists(dir_name):
        os.makedirs(dir_name)

    video = open(src_path, format=args.format)
    frames = frame_iter(video)

    sum_ = None

    for fi, frame in enumerate(frame_iter(video)):

        if sum_ is None:
            sum_ = frame.to_nd_array().astype(float)
        else:
            sum_ += frame.to_nd_array().astype(float)

    sum_ /= (fi + 1)

    dst_path = os.path.join('sandbox', os.path.basename(src_path) + '-avg.jpeg')
    print 'writing', (fi + 1), 'frames to', dst_path
    
    cv2.imwrite(dst_path, sum_)

