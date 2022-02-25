#!/usr/bin/env python3

from fractions import Fraction
import colorsys

import numpy as np

import av


(width, height) = (640, 360)
total_frames = 20
fps = 30

container = av.open("generate_video_with_pts.mp4", mode="w")

stream = container.add_stream("mpeg4", rate=fps)  # alibi frame rate
stream.width = width
stream.height = height
stream.pix_fmt = "yuv420p"

# ffmpeg time is complicated
# more at https://github.com/PyAV-Org/PyAV/blob/main/docs/api/time.rst
# our situation is the "encoding" one

# this is independent of the "fps" you give above
# 1/1000 means milliseconds (and you can use that, no problem)
# 1/2 means half a second (would be okay for the delays we use below)
# 1/30 means ~33 milliseconds
# you should use the least fraction that makes sense for you
stream.codec_context.time_base = Fraction(1, fps)

# this says when to show the next frame
# (increment by how long the current frame will be shown)
my_pts = 0  # [seconds]
# below we'll calculate that into our chosen time base

# we'll keep this frame around to draw on this persistently
# you can also redraw into a new object every time but you needn't
the_canvas = np.zeros((height, width, 3), dtype=np.uint8)
the_canvas[:, :] = (32, 32, 32)  # some dark gray background because why not
block_w2 = int(0.5 * width / total_frames * 0.75)
block_h2 = int(0.5 * height / 4)

for frame_i in range(total_frames):

    # move around the color wheel (hue)
    nice_color = colorsys.hsv_to_rgb(frame_i / total_frames, 1.0, 1.0)
    nice_color = (np.array(nice_color) * 255).astype(np.uint8)

    # draw blocks of a progress bar
    cx = int(width / total_frames * (frame_i + 0.5))
    cy = int(height / 2)
    the_canvas[
        cy - block_h2 : cy + block_h2, cx - block_w2 : cx + block_w2
    ] = nice_color

    frame = av.VideoFrame.from_ndarray(the_canvas, format="rgb24")

    # seconds -> counts of time_base
    frame.pts = int(round(my_pts / stream.codec_context.time_base))

    # increment by display time to pre-determine next frame's PTS
    my_pts += 1.0 if ((frame_i // 3) % 2 == 0) else 0.5
    # yes, the last frame has no "duration" because nothing follows it
    # frames don't have duration, only a PTS

    for packet in stream.encode(frame):
        container.mux(packet)

# finish it with a blank frame, so the "last" frame actually gets shown for some time
# this black frame will probably be shown for 1/fps time
# at least, that is the analysis of ffprobe
the_canvas[:] = 0
frame = av.VideoFrame.from_ndarray(the_canvas, format="rgb24")
frame.pts = int(round(my_pts / stream.codec_context.time_base))
for packet in stream.encode(frame):
    container.mux(packet)

# the time should now be 15.5 + 1/30 = 15.533

# without that last black frame, the real last frame gets shown for 1/30
# so that video would have been 14.5 + 1/30 = 14.533 seconds long

# Flush stream
for packet in stream.encode():
    container.mux(packet)

# Close the file
container.close()
