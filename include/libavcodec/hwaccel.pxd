cdef extern from "libavcodec/avcodec.h" nogil:
    cdef enum:
        AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX,
        AV_CODEC_HW_CONFIG_METHOD_HW_FRAMES_CTX,
        AV_CODEC_HW_CONFIG_METHOD_INTERNAL,
        AV_CODEC_HW_CONFIG_METHOD_AD_HOC,
    cdef struct AVCodecHWConfig:
        AVPixelFormat pix_fmt
        int methods
        AVHWDeviceType device_type
    cdef const AVCodecHWConfig* avcodec_get_hw_config(const AVCodec *codec, int index)
    cdef enum:
        AV_HWACCEL_CODEC_CAP_EXPERIMENTAL
    cdef struct AVHWAccel:
        char *name
        AVMediaType type
        AVCodecID id
        AVPixelFormat pix_fmt
        int capabilities
