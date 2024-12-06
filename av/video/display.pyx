cimport libav as lib
from libc.stdint cimport int32_t

from av.sidedata.sidedata import SideData
from av.sidedata.sidedata import Type as SideDataType


def get_display_rotation(matrix):
    import numpy as np

    if not isinstance(matrix, SideData) or matrix.type != SideDataType.DISPLAYMATRIX:
        raise ValueError("Matrix must be `SideData` of type `DISPLAYMATRIX`")
    cdef const int32_t[:] view = np.frombuffer(matrix, dtype=np.int32)
    if view.shape[0] != 9:
        raise ValueError("Matrix must be 3x3 represented as a 9-element array")
    return lib.av_display_rotation_get(&view[0])

