from __future__ import print_function
import sys

import av

container = av.open(sys.argv[1])
duration = container.duration
stream = container.streams.video[0]

print('container.duration', duration, float(duration) / av.time_base)
print('container.time_base', av.time_base)
print('stream.duration', stream.duration)
print('stream.time_base', stream.time_base)
print('codec.time_base', stream.codec_context.time_base)
print('scale', float(stream.codec_context.time_base / stream.time_base))
print()

exit()

real_duration = float(duration) / av.time_base
steps = 120
tolerance = real_duration / (steps * 4)
print('real_duration', real_duration)
print()

def iter_frames():
    for packet in container.demux(stream):
        for frame in packet.decode():
            yield frame

for i in xrange(steps):

    time = real_duration * i / steps
    min_time = time - tolerance

    pts = time / stream.time_base

    print('seeking', time, pts)
    stream.seek(int(pts))

    skipped = 0
    for frame in iter_frames():
        ftime = float(frame.pts * stream.time_base)
        if ftime >= min_time:
            break
        skipped += 1
    else:
        print('    WARNING: iterated to the end')

    print('   ', skipped, frame.pts, float(frame.pts * stream.time_base)) # WTF is this stream.time_base?
