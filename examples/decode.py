import array
import argparse
import sys
import pprint

import Image

from av import open, time_base


arg_parser = argparse.ArgumentParser()
arg_parser.add_argument('path')
arg_parser.add_argument('-a', '--audio', action='store_true')
arg_parser.add_argument('-v', '--video', action='store_true')
arg_parser.add_argument('-s', '--subs', action='store_true')
arg_parser.add_argument('-c', '--count', type=int, default=10)
args = arg_parser.parse_args()

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

print len(video.streams), 'stream(s):'
for i, stream in enumerate(video.streams):
    print '\t%r' % stream
    print '\t\ttime_base: %r' % stream.time_base
    print '\t\tstart_time: %r' % stream.start_time
    print '\t\tduration: %r' % stream.duration
    print '\t\tbase_frame_rate: %.3f - %r' % (float(stream.base_frame_rate), stream.base_frame_rate)
    print '\t\tavg_frame_rate: %.3f' % float(stream.avg_frame_rate)

    print '\t\tcodec:', stream.codec

    if stream.type == b'audio':
        print '\t\taudio:'
        print '\t\t\tsample_rate: %s' % stream.rate
        print '\t\t\tchannels: %s' % stream.channels

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
    print '\tduration: %.3f' % float(packet.stream.time_base * packet.duration)
    print '\tpts: %.3f' % float(packet.stream.time_base * packet.pts)
    print '\tdts: %.3f' % float(packet.stream.time_base * packet.dts)
    
    for frame in packet.decode():

        frame_count += 1

        if packet.stream.type == 'video':
    
            print '\tdecoded:', frame
            print '\t\tpts: %.3f' % float(packet.stream.time_base * (frame.pts or 0))
        
        elif packet.stream.type == 'audio':
            print '\tdecoded:', frame
            print '\t\tsamples:', frame.samples
            print '\t\tformat:', frame.format.name
            print '\t\tlayout:', frame.layout.name
            print '\t\tpts: %.3f' % float(packet.stream.time_base * (frame.pts or 0))

        elif packet.stream.type == 'subtitle':
            
            sub = frame

            print '\t\tformat:', sub.format
            print '\t\tstart_display_time: %.3f' % float(packet.stream.time_base * sub.start_display_time)
            print '\t\tend_display_time: %.3f' % float(packet.stream.time_base * sub.end_display_time)
            print '\t\tpts: %.3f' % float(packet.stream.time_base * sub.pts)
            print '\t\trects: %d' % len(sub.rects)
            for rect in sub.rects:
                print '\t\t\t%r' % rect
                if rect.type == 'ass':
                    print '\t\t\t\tass: %r' % rect.ass
        
        if args.count and frame_count > args.count:
            exit()

    print
