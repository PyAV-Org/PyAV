import Image
import av


def frame_iter(video):
    streams = [s for s in video.streams if s.type == b'video']
    streams = [streams[0]]
    for packet in video.demux(streams):
        for frame in packet.decode():
            yield frame


video = av.open('sandbox/640x360.mp4')
frames = frame_iter(video)
for frame in frames:
    img = Image.frombuffer("RGBA", (frame.width, frame.height), frame.to_rgba(), "raw", "RGBA", 0, 1)
