from libc.stdint cimport int32_t

from collections.abc import Mapping
from enum import Enum

from av.sidedata.motionvectors import MotionVectors


cdef object _cinit_bypass_sentinel = object()


class Type(Enum):
    """
    Enum class representing different types of frame data in audio/video processing.
    Values are mapped to corresponding AV_FRAME_DATA constants from FFmpeg.

    From: https://github.com/FFmpeg/FFmpeg/blob/master/libavutil/frame.h
    """
    PANSCAN = lib.AV_FRAME_DATA_PANSCAN
    A53_CC = lib.AV_FRAME_DATA_A53_CC
    STEREO3D = lib.AV_FRAME_DATA_STEREO3D
    MATRIXENCODING = lib.AV_FRAME_DATA_MATRIXENCODING
    DOWNMIX_INFO = lib.AV_FRAME_DATA_DOWNMIX_INFO
    REPLAYGAIN = lib.AV_FRAME_DATA_REPLAYGAIN
    DISPLAYMATRIX = lib.AV_FRAME_DATA_DISPLAYMATRIX
    AFD = lib.AV_FRAME_DATA_AFD
    MOTION_VECTORS = lib.AV_FRAME_DATA_MOTION_VECTORS
    SKIP_SAMPLES = lib.AV_FRAME_DATA_SKIP_SAMPLES
    AUDIO_SERVICE_TYPE = lib.AV_FRAME_DATA_AUDIO_SERVICE_TYPE
    MASTERING_DISPLAY_METADATA = lib.AV_FRAME_DATA_MASTERING_DISPLAY_METADATA
    GOP_TIMECODE = lib.AV_FRAME_DATA_GOP_TIMECODE
    SPHERICAL = lib.AV_FRAME_DATA_SPHERICAL
    CONTENT_LIGHT_LEVEL = lib.AV_FRAME_DATA_CONTENT_LIGHT_LEVEL
    ICC_PROFILE = lib.AV_FRAME_DATA_ICC_PROFILE
    S12M_TIMECODE = lib.AV_FRAME_DATA_S12M_TIMECODE
    DYNAMIC_HDR_PLUS = lib.AV_FRAME_DATA_DYNAMIC_HDR_PLUS
    REGIONS_OF_INTEREST = lib.AV_FRAME_DATA_REGIONS_OF_INTEREST
    VIDEO_ENC_PARAMS = lib.AV_FRAME_DATA_VIDEO_ENC_PARAMS
    SEI_UNREGISTERED = lib.AV_FRAME_DATA_SEI_UNREGISTERED
    FILM_GRAIN_PARAMS = lib.AV_FRAME_DATA_FILM_GRAIN_PARAMS
    DETECTION_BBOXES = lib.AV_FRAME_DATA_DETECTION_BBOXES
    DOVI_RPU_BUFFER = lib.AV_FRAME_DATA_DOVI_RPU_BUFFER
    DOVI_METADATA = lib.AV_FRAME_DATA_DOVI_METADATA
    DYNAMIC_HDR_VIVID = lib.AV_FRAME_DATA_DYNAMIC_HDR_VIVID
    AMBIENT_VIEWING_ENVIRONMENT = lib.AV_FRAME_DATA_AMBIENT_VIEWING_ENVIRONMENT
    VIDEO_HINT = lib.AV_FRAME_DATA_VIDEO_HINT


cdef SideData wrap_side_data(Frame frame, int index):
    if frame.ptr.side_data[index].type == lib.AV_FRAME_DATA_MOTION_VECTORS:
        return MotionVectors(_cinit_bypass_sentinel, frame, index)
    else:
        return SideData(_cinit_bypass_sentinel, frame, index)


cdef int get_display_rotation(Frame frame):
    for i in range(frame.ptr.nb_side_data):
        if frame.ptr.side_data[i].type == lib.AV_FRAME_DATA_DISPLAYMATRIX:
            return int(lib.av_display_rotation_get(<const int32_t *>frame.ptr.side_data[i].data))
    return 0


cdef class SideData(Buffer):
    def __init__(self, sentinel, Frame frame, int index):
        if sentinel is not _cinit_bypass_sentinel:
            raise RuntimeError("cannot manually instatiate SideData")
        self.frame = frame
        self.ptr = frame.ptr.side_data[index]
        self.metadata = wrap_dictionary(self.ptr.metadata)

    cdef size_t _buffer_size(self):
        return self.ptr.size

    cdef void* _buffer_ptr(self):
        return self.ptr.data

    cdef bint _buffer_writable(self):
        return False

    def __repr__(self):
        return f"<av.sidedata.{self.__class__.__name__} {self.ptr.size} bytes of {self.type} at 0x{<unsigned int>self.ptr.data:0x}>"

    @property
    def type(self):
        return Type(self.ptr.type)


cdef class _SideDataContainer:
    def __init__(self, Frame frame):
        self.frame = frame
        self._by_index = []
        self._by_type = {}

        cdef int i
        cdef SideData data
        for i in range(self.frame.ptr.nb_side_data):
            data = wrap_side_data(frame, i)
            self._by_index.append(data)
            self._by_type[data.type] = data

    def __len__(self):
        return len(self._by_index)

    def __iter__(self):
        return iter(self._by_index)

    def __getitem__(self, key):
        if isinstance(key, int):
            return self._by_index[key]
        if isinstance(key, str):
            return self._by_type[Type[key]]
        return self._by_type[key]


class SideDataContainer(_SideDataContainer, Mapping):
    pass
