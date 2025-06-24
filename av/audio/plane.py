import cython
from cython.cimports.av.audio.frame import AudioFrame


@cython.cclass
class AudioPlane(Plane):
    def __cinit__(self, frame: AudioFrame, index: cython.int):
        # Only the first linesize is ever populated, but it applies to every plane.
        self.buffer_size = self.frame.ptr.linesize[0]

    @cython.cfunc
    def _buffer_size(self) -> cython.size_t:
        return self.buffer_size
