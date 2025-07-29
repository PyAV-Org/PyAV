import av

av.logging.set_level(av.logging.VERBOSE)

"""
This is written for MacOS. Other platforms will need a different file, format pair.
You may need to change the file "1". Use this command to list all devices:

 ffmpeg -f avfoundation -list_devices true -i ""

"""

input_ = av.open("1", format="avfoundation")
output = av.open("out.mkv", "w")

# Prefer x264, but use Apple hardware if not available.
try:
    encoder = av.Codec("libx264", "w").name
except av.FFmpegError:
    encoder = "h264_videotoolbox"

output_stream = output.add_stream(encoder, rate=30)
output_stream.width = input_.streams.video[0].width
output_stream.height = input_.streams.video[0].height
output_stream.pix_fmt = "yuv420p"

try:
    while True:
        try:
            for frame in input_.decode(video=0):
                packet = output_stream.encode(frame)
                output.mux(packet)
        except av.BlockingIOError:
            pass
except KeyboardInterrupt:
    print("Recording stopped by user")

packet = output_stream.encode(None)
output.mux(packet)

input_.close()
output.close()
