from .frame import VideoFrame

class VideoPlane:
    line_size: int
    width: int
    height: int
    buffer_size: int

    def __init__(self, frame: VideoFrame, index: int): ...
