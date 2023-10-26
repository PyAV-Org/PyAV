cdef extern from "libavcodec/defs.h" nogil:

    cdef enum AVFieldOrder:
        AV_FIELD_UNKNOWN
        AV_FIELD_PROGRESSIVE
        AV_FIELD_TT
        AV_FIELD_BB
        AV_FIELD_TB
        AV_FIELD_BT

    cdef enum AVDiscard:
        AVDISCARD_NONE
        AVDISCARD_DEFAULT
        AVDISCARD_NONREF
        AVDISCARD_BIDIR
        AVDISCARD_NONINTRA
        AVDISCARD_NONKEY
        AVDISCARD_ALL
