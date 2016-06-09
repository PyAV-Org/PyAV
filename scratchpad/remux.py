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
arg_parser.add_argument('input')
arg_parser.add_argument('output')
arg_parser.add_argument('-F', '--iformat')
arg_parser.add_argument('-O', '--ioption', action='append', default=[])
arg_parser.add_argument('-f', '--oformat')
arg_parser.add_argument('-o', '--ooption', action='append', default=[])
arg_parser.add_argument('-a', '--noaudio', action='store_true')
arg_parser.add_argument('-v', '--novideo', action='store_true')
arg_parser.add_argument('-s', '--nosubs', action='store_true')
arg_parser.add_argument('-d', '--nodata', action='store_true')
arg_parser.add_argument('-c', '--count', type=int, default=0)
args = arg_parser.parse_args()


input_ = open(args.input,
    format=args.iformat,
    options=dict(x.split('=') for x in args.ioption),
)
output = open(args.output, 'w',
    format=args.oformat,
    options=dict(x.split('=') for x in args.ooption),
)

in_to_out = {}

for i, stream in enumerate(input_.streams):

    if (
        (stream.type == b'audio' and not args.noaudio) or
        (stream.type == b'video' and not args.novideo) or
        (stream.type == b'subtitle' and not args.nosubtitle) or
        (stream.type == b'data' and not args.nodata)
    ):
        in_to_out[stream] = ostream = output.add_stream(template=stream)

for i, packet in enumerate(input_.demux(in_to_out.keys())):

    if args.count and i >= args.count:
        break
    print '%02d %r' % (i, packet)
    print '\tin: ', packet.stream

    if packet.dts is None:
        continue

    packet.stream = in_to_out[packet.stream]

    print '\tout:', packet.stream

    output.mux(packet)


output.close()

