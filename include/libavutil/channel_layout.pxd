cdef extern from "libavutil/channel_layout.h" nogil:

    # This is not a comprehensive list.
    cdef uint64_t AV_CH_LAYOUT_MONO
    cdef uint64_t AV_CH_LAYOUT_STEREO
    cdef uint64_t AV_CH_LAYOUT_2POINT1
    cdef uint64_t AV_CH_LAYOUT_4POINT0
    cdef uint64_t AV_CH_LAYOUT_5POINT0_BACK
    cdef uint64_t AV_CH_LAYOUT_5POINT1_BACK
    cdef uint64_t AV_CH_LAYOUT_6POINT1
    cdef uint64_t AV_CH_LAYOUT_7POINT1
