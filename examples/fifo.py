import array
import argparse
import sys
import pprint
import subprocess

import Image
import av


def print_data(frame):
    for i, plane in enumerate(frame.planes or ()):
        data = plane.to_bytes()
        print '\tPLANE %d, %d bytes' % (i, len(data))
        data = data.encode('hex')
        for i in xrange(0, len(data), 128):
            print '\t\t\t%s' % data[i:i + 128]


arg_parser = argparse.ArgumentParser()
arg_parser.add_argument('path')
arg_parser.add_argument('-p', '--play', action='store_true')
arg_parser.add_argument('-d', '--data', action='store_true')
arg_parser.add_argument('-s', '--size', type=int, default=1024)
arg_parser.add_argument('-c', '--count', type=int, default=5)
args = arg_parser.parse_args()

ffplay = None

container = av.open(args.path)
stream = next(s for s in container.streams if s.type == 'audio')

fifo = av.AudioFifo()

input_count = 0
output_count = 0

for i, packet in enumerate(container.demux(stream)):
    for frame in packet.decode():
        input_count += 1
        
        print '<<< %04d     ' % i, frame

        if args.data:
            print_data(frame)

        fifo.write(frame)
        while frame:
            frame = fifo.read(args.size)
            if frame:
                output_count += 1
                print '>>>      %04d' % output_count, frame
                if args.data:
                    print_data(frame)

                if args.play:
                    if not ffplay:
                        cmd = ['ffplay',
                            '-f', 's16le',
                            '-ar', str(stream.rate),
                            '-vn','-',
                        ]
                        print '*** ****', ' '.join(cmd)
                        ffplay = subprocess.Popen(cmd, stdin=subprocess.PIPE)
                    try:
                        ffplay.stdin.write(frame.planes[0].to_bytes())
                    except IOError as e:
                        print e
                        exit()


        if args.count and input_count >= args.count:
            exit()

