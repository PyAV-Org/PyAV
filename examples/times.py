import sys
import pprint

import Image

from av import open
import av.format

video = open(sys.argv[1])

print 'duration:', float(video.duration) / av.format.time_base
print len(video.streams), 'stream(s):'
for i, stream in enumerate(video.streams):
    print '    %r' % stream
    print '        time_base: %r' % stream.time_base
    print '        start_time: %r' % stream.start_time
    print '        duration: %r' % stream.duration
    print '        base_frame_rate: %.3f - %r' % (float(stream.base_frame_rate), stream.base_frame_rate)
    print '        avg_frame_rate: %.3f' % float(stream.avg_frame_rate)



streams = [s for s in video.streams if s.type in (b'video', b'audio')]


frame_count = 0

for i, packet in enumerate(video.demux(streams)):
    
    print 'packet %d:' % (i + 1)
    print '    duration: %.3f' % float(packet.stream.time_base * packet.duration)
    print '    pts: %.3f' % float(packet.stream.time_base * packet.pts)
    print '    dts: %.3f' % float(packet.stream.time_base * packet.dts)
    
    for frame in packet.decode():
        frame_count += 1
        print 'frame %d:' % frame_count
        print '    frame pts: %.3f' % float(packet.stream.time_base * frame.pts)

        