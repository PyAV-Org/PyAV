cdef extern from "libavutil/avutil.h" nogil:

   cdef enum AVSampleFormat:
      AV_SAMPLE_FMT_NONE
      AV_SAMPLE_FMT_U8
      AV_SAMPLE_FMT_S16
      AV_SAMPLE_FMT_S32
      AV_SAMPLE_FMT_FLT
      AV_SAMPLE_FMT_DBL
      AV_SAMPLE_FMT_U8P
      AV_SAMPLE_FMT_S16P
      AV_SAMPLE_FMT_S32P
      AV_SAMPLE_FMT_FLTP
      AV_SAMPLE_FMT_DBLP
      AV_SAMPLE_FMT_NB
