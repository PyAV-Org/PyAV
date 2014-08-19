import array
import argparse
import sys
import pprint
import subprocess

from PIL import Image
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
arg_parser.add_argument('-f', '--format')
arg_parser.add_argument('-l', '--layout')
arg_parser.add_argument('-r', '--rate', type=int)
arg_parser.add_argument('-s', '--size', type=int, default=1024)
arg_parser.add_argument('-c', '--count', type=int, default=5)
args = arg_parser.parse_args()

ffplay = None

container = av.open(args.path)
stream = next(s for s in container.streams if s.type == 'audio')

fifo = av.AudioFifo() if args.size else None
resampler = av.AudioResampler(
    format=av.AudioFormat(args.format or stream.format.name).packed if args.format else None,
    layout=int(args.layout) if args.layout and args.layout.isdigit() else args.layout,
    rate=args.rate,
) if (args.format or args.layout or args.rate) else None

read_count = 0
fifo_count = 0
sample_count = 0

for i, packet in enumerate(container.demux(stream)):

    for frame in packet.decode():

        read_count += 1
        print '>>>> %04d' % read_count, frame
        if args.data:
            print_data(frame)

        frames = [frame]

        if resampler:
            for i, frame in enumerate(frames):
                frame = resampler.resample(frame)
                print 'RESAMPLED', frame
                if args.data:
                    print_data(frame)
                frames[i] = frame

        if fifo:

            to_process = frames
            frames = []

            for frame in to_process:
                fifo.write(frame)
                while frame:
                    frame = fifo.read(args.size)
                    if frame:
                        fifo_count += 1
                        print '|||| %04d' % fifo_count, frame
                        if args.data:
                            print_data(frame)
                        frames.append(frame)

        if frames and args.play:
            if not ffplay:
                cmd = ['ffplay',
                    '-f', frames[0].format.packed.container_name,
                    '-ar', str(args.rate or stream.rate),
                    '-ac', str(len(resampler.layout.channels if resampler else stream.layout.channels)),
                    '-vn','-',
                ]
                print 'PLAY', ' '.join(cmd)
                ffplay = subprocess.Popen(cmd, stdin=subprocess.PIPE)
            try:
                for frame in frames:
                    ffplay.stdin.write(frame.planes[0].to_bytes())
            except IOError as e:
                print e
                exit()

        if args.count and read_count >= args.count:
            exit()

