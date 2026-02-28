cdef extern from "libavdevice/avdevice.h" nogil:
    cdef int avdevice_version()
    cdef char* avdevice_configuration()
    cdef char* avdevice_license()
    void avdevice_register_all()

    cdef struct AVDeviceInfo:
        char *device_name
        char *device_description
        int nb_media_types
        AVMediaType *media_types

    cdef struct AVDeviceInfoList:
        AVDeviceInfo **devices
        int nb_devices
        int default_device

    int avdevice_list_input_sources(
        const AVInputFormat *device,
        const char *device_name,
        AVDictionary *device_options,
        AVDeviceInfoList **device_list,
    )
    int avdevice_list_output_sinks(
        const AVOutputFormat *device,
        const char *device_name,
        AVDictionary *device_options,
        AVDeviceInfoList **device_list,
    )
    void avdevice_free_list_devices(AVDeviceInfoList **device_list)
