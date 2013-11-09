import logging
import os
import sys

import av
from tests.common import asset, sandboxed


# open input file
input_file_path = sys.argv[1] if len(sys.argv) > 1 else asset('320x240x4.mov')
input_file = av.open(input_file_path)

input_video_stream = None
input_audio_stream = None

input_streams = []

# find first video stream
for stream in input_file.streams:
    if stream.type == 'video':
        input_video_stream = stream
        input_streams.append(input_video_stream)
        break

# find first audio stream
for stream in input_file.streams:
    if stream.type == 'audio':
        input_audio_stream = stream
        input_streams.append(input_audio_stream)
        break

# open output file
output_file_path = sandboxed('encoded-' + os.path.basename(input_file_path))
output_file = av.open(output_file_path, 'w')

output_video_stream = None
output_audio_stream = None

if input_video_stream:
    
    # setup video output stream
    output_video_stream = output_file.add_stream("mpeg4", input_video_stream.base_frame_rate)
    
    codec = output_video_stream.codec
    
    # set output size
    codec.width = 640
    codec.height = 480
    
    # set bit rate and pix_fmt
    #codec.bit_rate = 256000
    codec.pix_fmt = "yuv420p"
    
    

if input_audio_stream:
    
    # setup audio output stream
    output_audio_stream = output_file.add_stream("mp3")
    
    codec = output_audio_stream.codec
    
    codec.bit_rate = 128000
    codec.sample_rate = 44100
    codec.channel_layout = "stereo"
    
    codec.sample_fmt = "s16p"
    

output_file.dump()

frame_count = 0

# demux the input file
for packet in input_file.demux(input_streams):
    
    # decode the frames in the packet
    for frame in packet.decode():
        
        encoded_packet = None
        
        if packet.stream.type == b'audio':
            # encode audio frame
            encoded_packet = output_audio_stream.encode(frame)
        else:
            # encode video frame
            encoded_packet = output_video_stream.encode(frame)

            if frame_count % 10 == 0:
                if frame_count:
                    print
                print ('%03d:' % frame_count), 
            sys.stdout.write('.')
            sys.stdout.flush()

            frame_count += 1
            
        if encoded_packet:
                # Add encoded packet to output file
                output_file.mux(encoded_packet)
        
    if frame_count >= 100:
        break

print

# Finally we need to flush out the frames that are buffered in the encoder.
# To do that we simply call encode with no args until we get a None returned
if output_audio_stream:
    while True:
        packet =  output_audio_stream.encode()
        if packet:
            print "flushed out audio packet", packet
            output_file.mux(packet)
        else:
            break

while True:
    packet =  output_video_stream.encode()
    if packet:
        print "flushed out video packet", packet
        output_file.mux(packet)
    else:
        break

# now close the files
# if you don't close the output file the trailer will not be written
input_file.close()
output_file.close()

