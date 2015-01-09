from __future__ import division

import argparse
import resource
import gc

import av


parser = argparse.ArgumentParser()
parser.add_argument('-c', '--count', type=int, default=5)
parser.add_argument('-f', '--frames', type=int, default=100)
parser.add_argument('--print', dest='print_', action='store_true')
parser.add_argument('--to-rgb', action='store_true')
parser.add_argument('--to-image', action='store_true')
parser.add_argument('--gc', '-g', action='store_true')
parser.add_argument('input')
args = parser.parse_args()

def format_bytes(n):
    order = 0
    while n > 1024:
        order += 1
        n //= 1024
    return '%d%sB' % (n, ('', 'k', 'M', 'G', 'T', 'P')[order])

usage = []

for round_ in xrange(args.count):
    
    print 'Round %d/%d:' % (round_ + 1, args.count)

    if args.gc:
        gc.collect()

    usage.append(resource.getrusage(resource.RUSAGE_SELF))

    fh = av.open(args.input)
    vs = next(s for s in fh.streams if s.type == 'video')

    fi = 0
    for packet in fh.demux([vs]):
        for frame in packet.decode():
            if args.print_:
                print frame
            if args.to_rgb:
                print frame.to_rgb()
            if args.to_image:
                print frame.to_image()
            fi += 1
        if fi > args.frames:
            break

    frame = packet = fh = vs = None



usage.append(resource.getrusage(resource.RUSAGE_SELF))

for i in xrange(len(usage) - 1):
    before = usage[i]
    after = usage[i + 1]
    print '%s (%s)' % (format_bytes(after.ru_maxrss), format_bytes(after.ru_maxrss - before.ru_maxrss))

