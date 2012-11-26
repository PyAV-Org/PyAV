import sys

from av import open


video = open(sys.argv[1])

print 'DUMP'
print '====='
video.dump()
print '-----'
print

print len(video.streams), 'stream(s):'
for i, stream in enumerate(video.streams):
    print '\t', i, stream


