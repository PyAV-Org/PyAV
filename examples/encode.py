import argparse
import logging
import os
import sys

import av
from tests.common import asset, sandboxed


arg_parser = argparse.ArgumentParser()
arg_parser.add_argument('-v', '--verbose', action='store_true')
arg_parser.add_argument('input', nargs=1)
args = arg_parser.parse_args()

input_file = av.open(args.input[0])
input_video_stream = None # next((s for s in input_file.streams if s.type == 'video'), None)
input_audio_stream = next((s for s in input_file.streams if s.type == 'audio'), None)

# open output file
output_file_path = sandboxed('encoded-' + os.path.basename(args.input[0]))
output_file = av.open(output_file_path, 'w')
output_video_stream = output_file.add_stream("mpeg4", 24) if input_video_stream else None
output_audio_stream = output_file.add_stream("mp3") if input_audio_stream else None


frame_count = 0


for packet in input_file.demux([s for s in (input_video_stream, input_audio_stream) if s]):


    if args.verbose:
        print 'in ', packet

    for frame in packet.decode():
        
        if args.verbose:
            print '\t%s' % frame

        if packet.stream.type == b'video':
            if frame_count % 10 == 0:
                if frame_count:
                    print
                print ('%03d:' % frame_count), 
            sys.stdout.write('.')
            sys.stdout.flush()

            frame_count += 1

        # Signal to generate it's own timestamps.
        frame.pts = None
        
        stream = output_audio_stream if packet.stream.type == b'audio' else output_video_stream
        output_packets = [output_audio_stream.encode(frame)]
        while output_packets[-1]:
            output_packets.append(output_audio_stream.encode(None))
            
        for p in output_packets:
            if p:
                if args.verbose:
                    print 'OUT', p
                output_file.mux(p)
        
    if frame_count >= 100:
        break

print '-' * 78

# Finally we need to flush out the frames that are buffered in the encoder.
# To do that we simply call encode with no args until we get a None returned
if output_audio_stream:
    while True:
        output_packet = output_audio_stream.encode(None)
        if output_packet:
            if args.verbose:
                print '<<<', output_packet
            output_file.mux(output_packet)
        else:
            break

if output_video_stream:
    while True:
        output_packet = output_video_stream.encode(None)
        if output_packet:
            if args.verbose:
                print '<<<', output_packet
            output_file.mux(output_packet)
        else:
            break

output_file.close()

