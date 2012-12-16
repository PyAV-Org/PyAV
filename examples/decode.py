import sys
import pprint

import Image

from av import open
import av.format

video = open(sys.argv[1])

print 'DUMP'
print '====='
video.dump()
print '-----'
print

print 'duration:', float(video.duration) / av.format.time_base

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
    print '        metadata:'
    for k, v in sorted(stream.metadata.iteritems()):
        print '            %s: %r' % (k, v)


streams = [s for s in video.streams if s.type == b'video']
streams = [streams[0]]


for i, packet in enumerate(video.demux(streams)):
    
    print '%4d %r' % (i, packet)
    print '    duration: %.3f' % float(packet.stream.time_base * packet.duration)
    print '    pts: %.3f' % float(packet.stream.time_base * packet.pts)
    print '    dts: %.3f' % float(packet.stream.time_base * packet.dts)
    
    if packet.stream.type == 'video':
        frame = packet.decode()
        if not frame:
            continue
        print '    decoded:', frame
        print '               pts:', frame.pts
        print '               bts:', frame.timestamp
        
        # img = Image.frombuffer("RGBA", (frame.width, frame.height), frame.rgba, "raw", "RGBA", 0, 1)
        # img.save('sandbox/frame_%04d.jpg' % video_count)
    
    elif packet.stream.type == 'subtitle':
        
        sub = packet.decode()
        print '    decoded:', sub
        if not sub:
            continue
        
        print '        format:', sub.format
        print '        start_display_time: %.3f' % float(packet.stream.time_base * sub.start_display_time)
        print '        end_display_time: %.3f' % float(packet.stream.time_base * sub.end_display_time)
        print '        pts: %.3f' % float(packet.stream.time_base * sub.pts)
        print '        rects: %d' % len(sub.rects)
        for rect in sub.rects:
            print '            %r' % rect
            if rect.type == 'ass':
                print '                ass: %r' % rect.ass
    
    if i > 10:
        break