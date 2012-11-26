import sys
import pprint

from av import open


video = open(sys.argv[1])

print 'DUMP'
print '====='
video.dump()
print '-----'
print

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
    print '        base_frame_rate: %.3f' % float(stream.base_frame_rate)
    print '        avg_frame_rate: %.3f' % float(stream.avg_frame_rate)
    print '        metadata:'
    for k, v in sorted(stream.metadata.iteritems()):
        print '            %s: %r' % (k, v)


