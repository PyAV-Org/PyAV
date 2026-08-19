import cython
from cython.cimports.av.audio.frame import AudioFrame


@cython.final
@cython.cclass
class AudioPlane(Plane):
    def __cinit__(self, frame: AudioFrame, index: cython.int):
        nb_planes: cython.int = (
            frame.layout.nb_channels if frame.format.is_planar else 1
        )
        if index < 0 or index >= nb_planes:
            raise ValueError(f"plane index {index} out of range for {nb_planes} planes")

    @cython.cfunc
    def _buffer_size(self) -> cython.size_t:
        # Only the first linesize is ever populated, but it applies to every plane.
        return self.frame.ptr.linesize[0]
