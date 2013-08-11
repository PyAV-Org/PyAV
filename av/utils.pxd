from libc.stdint cimport int64_t, uint8_t, uint64_t

cimport libav as lib


cdef int err_check(int res) except -1

cdef char* channel_layout_name(
    int nb_channels,
    uint64_t channel_layout)

# Conversions.
cdef dict avdict_to_dict(lib.AVDictionary *input)
cdef object avrational_to_faction(lib.AVRational *input)
cdef object to_avrational(object value, lib.AVRational *input)

cdef object av_frac_to_fraction(lib.AVFrac *input)

cdef int samples_alloc_array_and_samples(
        uint8_t ***audio_data, 
        int *linesize, int nb_channels,
        int nb_samples, 
        lib.AVSampleFormat sample_fmt,
        int align
        )


