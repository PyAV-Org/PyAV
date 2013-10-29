import sys
import pprint

import Image

from av import open
from av.context import time_base

video = open(sys.argv[1])

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
    print '    %r' % stream
    print '        time_base: %r' % stream.time_base
    print '        start_time: %r' % stream.start_time
    print '        duration: %r' % stream.duration
    print '        base_frame_rate: %.3f - %r' % (float(stream.base_frame_rate), stream.base_frame_rate)
    print '        avg_frame_rate: %.3f' % float(stream.avg_frame_rate)

    if stream.type == b'audio':
        print '        audio:'
        print '            sample_rate: %s' % stream.sample_rate
        print '            channels: %s' % stream.channels

    print '        metadata:'
    for k, v in sorted(stream.metadata.iteritems()):
        print '            %s: %r' % (k, v)


streams = [s for s in video.streams if s.type in (b'video', b'audio')]


frame_count = 0

for i, packet in enumerate(video.demux(streams)):
    
    print '%4d %r' % (i, packet)
    print '    duration: %.3f' % float(packet.stream.time_base * packet.duration)
    print '    pts: %.3f' % float(packet.stream.time_base * packet.pts)
    print '    dts: %.3f' % float(packet.stream.time_base * packet.dts)
    
    for frame in packet.decode():
        if packet.stream.type == 'video':

            frame_count += 1
    
            print '    decoded:', frame
            print '               pts: %.3f' % float(packet.stream.time_base * frame.pts)
        
        elif packet.stream.type == 'subtitle':
            
            sub = frame

            print '        format:', sub.format
            print '        start_display_time: %.3f' % float(packet.stream.time_base * sub.start_display_time)
            print '        end_display_time: %.3f' % float(packet.stream.time_base * sub.end_display_time)
            print '        pts: %.3f' % float(packet.stream.time_base * sub.pts)
            print '        rects: %d' % len(sub.rects)
            for rect in sub.rects:
                print '            %r' % rect
                if rect.type == 'ass':
                    print '                ass: %r' % rect.ass
        
        if frame_count > 5:
            break