import argparse
import os
import sys
import pprint
import itertools
import multiprocessing
import traceback

from PIL import Image

import av

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


def go(src_path):

    try:
        print src_path

        basename = os.path.splitext(os.path.basename(src_path))[0]
        dir_name = os.path.join('sandbox', basename)
        if not os.path.exists(dir_name):
            os.makedirs(dir_name)

        signal_path = os.path.join(dir_name, 'done')
        if os.path.exists(signal_path):
            print '   Already done.'
            return

        video = av.open(src_path, format=args.format)
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
                open(signal_path, 'w').write('done')
                break

            else:
                print '   Saved chunk', chunk_i, 'of', basename
                if chunk.size[0] != (chunk_i + 1):
                    chunk = chunk.crop((0, 0, frame_i + 1, chunk.size[1]))
                chunk.save(os.path.join(dir_name, '%s.%03d.jpg' % (basename, chunk_i)), quality=90)


    except Exception as e:
        print 'ERROR during', src_path, 'chunk', chunk_i
        traceback.print_exc()



if __name__ == '__main__':

    parser = argparse.ArgumentParser()
    parser.add_argument('-f', '--format')
    parser.add_argument('-n', '--frames', type=int, default=0)
    parser.add_argument('-P', '--pool', type=int)
    parser.add_argument('paths', nargs='+')
    args = parser.parse_args()

    if args.pool:
        pool = multiprocessing.Pool(args.pool)
        pool.map(go, args.paths)
    else:
        for path in args.paths:
            go(path)

