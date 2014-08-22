import argparse
import os
import sys
import pprint
import itertools

from PIL import Image

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

    print src_path

    basename = os.path.splitext(os.path.basename(src_path))[0]
    dir_name = os.path.join('sandbox', basename)
    if not os.path.exists(dir_name):
        os.makedirs(dir_name)

    video = open(src_path, format=args.format)
    frames = frame_iter(video)

    for chunk_i in itertools.count(1):

        chunk = None

        for frame_i, frame in itertools.izip(xrange(max_size), frames):

            if chunk is None:
                chunk = Image.new("RGB", (max_size, frame.height))

            img = frame.to_image()
            img = img.resize((1, frame.height), Image.ANTIALIAS)
            chunk.paste(img, (frame_i, 0))

        if chunk is None:
            # We are done here.
            break

        else:
            print 'Saved chunk', chunk_i
            if chunk.size[0] != (chunk_i + 1):
                chunk = chunk.crop((0, 0, frame_i + 1, chunk.size[1]))
            chunk.save(os.path.join(dir_name, '%s.%03d.jpg' % (basename, chunk_i)), quality=90)


