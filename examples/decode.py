import array
import argparse
import logging
import sys
import pprint
import subprocess

from PIL import Image

from av import open, time_base


logging.basicConfig(level=logging.DEBUG)


def format_time(time, time_base):
    if time is None:
        return 'None'
    return '%.3fs (%s or %s/%s)' % (time_base * time, time_base * time, time_base.numerator * time, time_base.denominator)


arg_parser = argparse.ArgumentParser()
arg_parser.add_argument('path')
arg_parser.add_argument('-f', '--format')
arg_parser.add_argument('-a', '--audio', action='store_true')
arg_parser.add_argument('-v', '--video', action='store_true')
arg_parser.add_argument('-s', '--subs', action='store_true')
arg_parser.add_argument('-d', '--data', action='store_true')
arg_parser.add_argument('-p', '--play', action='store_true')
arg_parser.add_argument('-o', '--option', action='append', default=[])
arg_parser.add_argument('-c', '--count', type=int, default=5)
args = arg_parser.parse_args()


proc = None

options = dict(x.split('=') for x in args.option)
video = open(args.path, format=args.format, options=options)

print 'container:', video
print '\tformat:', video.format
print '\tduration:', float(video.duration) / time_base
print '\tmetadata:'
for k, v in sorted(video.metadata.iteritems()):
    print '\t\t%s: %r' % (k, v)
print

print len(video.streams), 'stream(s):'
for i, stream in enumerate(video.streams):

    print '\t%r' % stream
    print '\t\ttime_base: %r' % stream.time_base
    print '\t\trate: %r' % stream.rate
    print '\t\tstart_time: %r' % stream.start_time
    print '\t\tduration: %s' % format_time(stream.duration, stream.time_base)
    print '\t\tbit_rate: %r' % stream.bit_rate
    print '\t\tbit_rate_tolerance: %r' % stream.bit_rate_tolerance

    if stream.type == b'audio':
        print '\t\taudio:'
        print '\t\t\tformat:', stream.format
        print '\t\t\tchannels: %s' % stream.channels

    elif stream.type == 'video':
        print '\t\tvideo:'
        print '\t\t\tformat:', stream.format
        print '\t\t\taverage_rate: %r' % stream.average_rate

    print '\t\tmetadata:'
    for k, v in sorted(stream.metadata.iteritems()):
        print '\t\t\t%s: %r' % (k, v)

    print


streams = [s for s in video.streams if
    (s.type == 'audio' and args.audio) or
    (s.type == 'video' and args.video) or
    (s.type == 'subtitle' and args.subs)
]


frame_count = 0

for i, packet in enumerate(video.demux(streams)):
    
    print '%02d %r' % (i, packet)
    print '\tduration: %s' % format_time(packet.duration, packet.stream.time_base)
    print '\tpts: %s' % format_time(packet.pts, packet.stream.time_base)
    print '\tdts: %s' % format_time(packet.dts, packet.stream.time_base)
    
    for frame in packet.decode():

        frame_count += 1

        print '\tdecoded:', frame
        print '\t\tpts:', format_time(frame.pts, packet.stream.time_base)

        if packet.stream.type == 'video':
            pass

        elif packet.stream.type == 'audio':
            print '\t\tsamples:', frame.samples
            print '\t\tformat:', frame.format.name
            print '\t\tlayout:', frame.layout.name

        elif packet.stream.type == 'subtitle':
            
            sub = frame

            print '\t\tformat:', sub.format
            print '\t\tstart_display_time:', format_time(sub.start_display_time, packet.stream.time_base)
            print '\t\tend_display_time:', format_time(sub.end_display_time, packet.stream.time_base)
            print '\t\trects: %d' % len(sub.rects)
            for rect in sub.rects:
                print '\t\t\t%r' % rect
                if rect.type == 'ass':
                    print '\t\t\t\tass: %r' % rect.ass
        
        if args.play and packet.stream.type == 'audio':
            if not proc:
                cmd = ['ffplay',
                    '-f', 's16le',
                    '-ar', str(packet.stream.time_base),
                    '-vn','-',
                ]
                proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
            try:
                proc.stdin.write(frame.planes[0].to_bytes())
            except IOError as e:
                print e
                exit()

        if args.data:
            print '\t\tdata'
            for i, plane in enumerate(frame.planes or ()):
                data = plane.to_bytes()
                print '\t\t\tPLANE %d, %d bytes' % (i, len(data))
                data = data.encode('hex')
                for i in xrange(0, len(data), 128):
                    print '\t\t\t%s' % data[i:i + 128]

        if args.count and frame_count >= args.count:
            exit()

    print
