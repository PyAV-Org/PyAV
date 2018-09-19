
import time
import sys

import av


start_time = last_time = time.monotonic()
def lap(name):
    global last_time
    now = time.monotonic()
    print(f'[{now - start_time:5.3f} (+{now - last_time:5.3f})] {name}')
    last_time = now


def v1(path):

    keyframes = []
    fh = av.open(path)
    stream = fh.streams.video[0]
    # stream.thread_type = 'AUTO'

    for pi, packet in enumerate(fh.demux(video=0)):
        if not packet.is_keyframe:
            continue

        lap(f'found keyframe {len(keyframes)} packet at {pi}')
        for frame in packet.decode():
            keyframes.append(frame)
        lap(f'decoded {len(keyframes)} frames')
        if len(keyframes) >= 3:
            break


def v2(path):

    keyframes = []
    fh = av.open(path)

    pcount = 0
    stream = fh.streams.video[0]
    # stream.thread_type = 'AUTO'

    demuxer = fh.demux(stream)

    frame_pts = (1 / stream.rate) / stream.time_base
    seek_pts = frame_pts // 2

    while True:

        for packet in demuxer:

            pcount += 1
            if not packet.is_keyframe:
                continue

            lap(f'found keyframe {len(keyframes)} packet at {pcount}')
            for frame in packet.decode():
                keyframes.append(frame)
            lap(f'decoded {len(keyframes)} frames')

            if len(keyframes) >= 3:
                return

            stream.seek(packet.pts + seek_pts, backward=False)




for path in sys.argv[1:]:
    lap(f'starting {path}')
    v1(path)

lap('done')
