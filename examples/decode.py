import array
import argparse
import sys
import pprint
import subprocess

import Image

from av import open, time_base


arg_parser = argparse.ArgumentParser()
arg_parser.add_argument('path')
arg_parser.add_argument('-a', '--audio', action='store_true')
arg_parser.add_argument('-v', '--video', action='store_true')
arg_parser.add_argument('-s', '--subs', action='store_true')
arg_parser.add_argument('-d', '--data', action='store_true')
arg_parser.add_argument('-p', '--play', action='store_true')
arg_parser.add_argument('-c', '--count', type=int, default=5)
args = arg_parser.parse_args()


proc = None

video = open(args.path)

print 'DUMP'
print '====='
video.dump()
print '-----'
print

print 'duration:', float(video.duration) / time_base

print 'Metadata:'
for k, v in sorted(video.metadata.iteritems()):
    print '    %s: %r' % (k, v)
print

def format_time(time, stream):
    if time is None:
        return 'None'
    return '%.3fs (%s or %s/%s)' % (stream.time_base * time, stream.time_base * time, stream.time_base.numerator * time, stream.time_base.denominator)

print len(video.streams), 'stream(s):'
for i, stream in enumerate(video.streams):

    print '\t%r' % stream
    print '\t\ttime_base: %r' % stream.time_base
    print '\t\trate: %r' % stream.rate
    print '\t\tstart_time: %r' % stream.start_time
    print '\t\tduration: %s' % format_time(stream.duration, stream)
    print '\t\tbit_rate: %r' % stream.bit_rate
    print '\t\tbit_rate_tolerance: %r' % stream.bit_rate_tolerance

    if stream.type == b'audio':
        print '\t\taudio:'
        print '\t\t\trate: %s' % stream.rate
        print '\t\t\tchannels: %s' % stream.channels

    elif stream.type == 'video':
        print '\t\tvideo:'
        print '\t\t\tguessed_rate: %r' % stream.guessed_rate
        print '\t\t\taverage_rate: %r' % stream.average_rate

    print '\t\tmetadata:'
    for k, v in sorted(stream.metadata.iteritems()):
        print '\t\t\t%s: %r' % (k, v)


streams = [s for s in video.streams if
    (s.type == 'audio' and args.audio) or
    (s.type == 'video' and args.video) or
    (s.type == 'subtitle' and args.subs)
]


frame_count = 0

for i, packet in enumerate(video.demux(streams)):
    
    print '%02d %r' % (i, packet)
    print '\tduration: %s' % format_time(packet.duration, packet.stream)
    print '\tpts: %s' % format_time(packet.pts, packet.stream)
    print '\tdts: %s' % format_time(packet.dts, packet.stream)
    
    for frame in packet.decode():

        frame_count += 1

        print '\tdecoded:', frame
        print '\t\tpts:', format_time(frame.pts, packet.stream)

        if packet.stream.type == 'video':
            pass

        elif packet.stream.type == 'audio':
            print '\t\tsamples:', frame.samples
            print '\t\tformat:', frame.format.name
            print '\t\tlayout:', frame.layout.name

        elif packet.stream.type == 'subtitle':
            
            sub = frame

            print '\t\tformat:', sub.format
            print '\t\tstart_display_time:', format_time(sub.start_display_time, packet.stream)
            print '\t\tend_display_time:', format_time(sub.end_display_time, packet.stream)
            print '\t\trects: %d' % len(sub.rects)
            for rect in sub.rects:
                print '\t\t\t%r' % rect
                if rect.type == 'ass':
                    print '\t\t\t\tass: %r' % rect.ass
        
        if args.play:
            if not proc:
                cmd = ['ffplay',
                    '-f', 's16le',
                    '-ar', str(packet.stream.rate),
                    '-vn','-',
                ]
                print '***', ' '.join(cmd)
                proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
            proc.stdin.write(frame.planes[0].to_bytes())

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
