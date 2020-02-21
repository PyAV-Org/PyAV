
cdef extern from "libavdevice/avdevice.h" nogil:

    cdef int   avdevice_version()
    cdef char* avdevice_configuration()
    cdef char* avdevice_license()
    void       avdevice_register_all()

    AVInputFormat * av_input_audio_device_next(AVInputFormat *d)
    AVInputFormat * av_input_video_device_next(AVInputFormat *d)
    AVOutputFormat * av_output_audio_device_next(AVOutputFormat *d)
    AVOutputFormat * av_output_video_device_next(AVOutputFormat *d)
