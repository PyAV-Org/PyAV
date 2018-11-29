import av
import av.datasets


in_fh = av.open(av.datasets.curated('pexels/time-lapse-video-of-night-sky-857195.mp4'))
raw_out_fh = open('night-sky.raw', 'wb')
bsf_out_fh = open('night-sky.h264', 'wb')

bsf = av.BitStreamFilterContext('h264_mp4toannexb')

for in_packet in in_fh.demux(video=0):
    raw_out_fh.write(in_packet)
    for out_packet in bsf(in_packet):
        bsf_out_fh.write(out_packet)
