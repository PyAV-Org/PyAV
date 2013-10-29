import resource
import sys

import av

path = sys.argv[1] if len(sys.argv) > 1 else 'sandbox/640x360.mp4'
DELINK = False


_last_rss = 0
def report():
    global _last_rss
    current = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    print '%d %d' % (current - _last_rss, current)
    _last_rss = current


print 'GLOBAL'
print '========='
for i in xrange(10):
    report() 
    container = av.open(path)
    codec = container.streams[0].codec
    if DELINK:
        container.streams[:] = []
    del container, codec
print

def local():
    print 'LOCAL'
    print '========='
    for i in xrange(10):
        report() 
        container = av.open(path)
        codec = container.streams[0].codec
        if DELINK:
            container.streams[:] = []
        del container, codec
local()
