cdef extern from "libavutil/hwcontext.h" nogil:

    enum AVHWDeviceType:
        AV_HWDEVICE_TYPE_NONE
        AV_HWDEVICE_TYPE_VDPAU
        AV_HWDEVICE_TYPE_CUDA
        AV_HWDEVICE_TYPE_VAAPI
        AV_HWDEVICE_TYPE_DXVA2
        AV_HWDEVICE_TYPE_QSV
        AV_HWDEVICE_TYPE_VIDEOTOOLBOX
        AV_HWDEVICE_TYPE_D3D11VA
        AV_HWDEVICE_TYPE_DRM
        AV_HWDEVICE_TYPE_OPENCL
        AV_HWDEVICE_TYPE_MEDIACODEC
        AV_HWDEVICE_TYPE_VULKAN
        AV_HWDEVICE_TYPE_D3D12VA

    cdef int av_hwdevice_ctx_create(AVBufferRef **device_ctx, AVHWDeviceType type, const char *device, AVDictionary *opts, int flags)

    cdef AVHWDeviceType av_hwdevice_find_type_by_name(const char *name)
    cdef const char *av_hwdevice_get_type_name(AVHWDeviceType type)
    cdef AVHWDeviceType av_hwdevice_iterate_types(AVHWDeviceType prev)

    cdef int av_hwframe_transfer_data(AVFrame *dst, const AVFrame *src, int flags)
