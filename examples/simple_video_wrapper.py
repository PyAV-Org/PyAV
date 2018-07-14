from typing import Sequence
import av


class VideoSequence(Sequence):
    """A video wrapper with index based frame access.

    The current behaviour is to return an array of RGB triplets for each frame.

    :param file: path to a supported video file.

    .. note::
        Slice based indexing is limited to a step size of 1.

    .. warning::
       This wrapper assumes that videos have a constant framerate.

    Example:

    >>> v = VideoSequence("video.mp4")
    >>> print(len(v))
    1851
    >>> v[0].shape
    (640, 480, 3)
    >>> subv = v[10:-10]
    >>> print(len(subv))
    1831
    """
    def __init__(self, file):
        self.file = file
        self.container = av.open(file)
        self.stream = self.container.streams.get(video=0)[0]
        self.frame_base = self.stream.time_base * self.stream.average_rate
        self.packet_iter = self.container.demux(self.stream)
        self.last_packet = next(self.packet_iter).decode()

        self.offset = 0
        self.duration = int(self.stream.duration * self.stream.time_base
                            * self.stream.average_rate)

    def __len__(self):
        return self.duration

    def __getitem__(self, t):
        # slicing support
        if isinstance(t, slice):
            start, stop, step = t.start, t.stop, t.step

            # defaults
            start = start or 0
            stop = stop or -1
            step = step or 1

            # range check
            if step != 1:
                raise IndexError("VideoSequence slicing is limited to step 1")
            if start < -len(self) or start >= len(self) \
                    or stop < -len(self) - 1 or stop > len(self):
                raise IndexError("VideoSequence slice index out of range.")

            # negative indexing
            start = start + len(self) if start < 0 else start
            stop = stop + len(self) if stop < 0 else stop
            stop = max(start, stop)

            video = VideoSequence(self.file)
            video.offset = self.offset + start  # cumulate offsets
            video.duration = stop - start

            return video

        # range check
        if t < -len(self) or t >= len(self):
            raise IndexError("VideoSequence index out of range.")

        # negative indexing
        if t < 0:
            t += len(self)

        t += self.offset

        t_pts = t / self.stream.time_base / self.stream.average_rate

        # Do seeking if needed
        if t > self.last_packet[-1].pts * self.frame_base + len(self.last_packet) \
                or t < self.last_packet[0].pts * self.frame_base:
            self.stream.seek(int(t / self.frame_base))
            self.packet_iter = self.container.demux(self.stream)

        while True:
            for f in self.last_packet:
                if f.pts == t_pts:
                    return f.to_rgb().to_nd_array()
            self.last_packet = next(self.packet_iter).decode()
