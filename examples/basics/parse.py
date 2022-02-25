import os
import subprocess

import av
import av.datasets


# We want an H.264 stream in the Annex B byte-stream format.
# We haven't exposed bitstream filters yet, so we're gonna use the `ffmpeg` CLI.
h264_path = "night-sky.h264"
if not os.path.exists(h264_path):
    subprocess.check_call(
        [
            "ffmpeg",
            "-i",
            av.datasets.curated("pexels/time-lapse-video-of-night-sky-857195.mp4"),
            "-vcodec",
            "copy",
            "-an",
            "-bsf:v",
            "h264_mp4toannexb",
            h264_path,
        ]
    )


fh = open(h264_path, "rb")

codec = av.CodecContext.create("h264", "r")

while True:

    chunk = fh.read(1 << 16)

    packets = codec.parse(chunk)
    print("Parsed {} packets from {} bytes:".format(len(packets), len(chunk)))

    for packet in packets:

        print("   ", packet)

        frames = codec.decode(packet)
        for frame in frames:
            print("       ", frame)

    # We wait until the end to bail so that the last empty `buf` flushes
    # the parser.
    if not chunk:
        break
