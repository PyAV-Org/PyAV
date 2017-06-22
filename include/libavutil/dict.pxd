cdef extern from "libavutil/dict.h" nogil:

    # See: http://ffmpeg.org/doxygen/trunk/structAVDictionary.html
    ctypedef struct AVDictionary:
        pass

    cdef void av_dict_free(AVDictionary **)

    # See: http://ffmpeg.org/doxygen/trunk/structAVDictionaryEntry.html
    ctypedef struct AVDictionaryEntry:
        char *key
        char *value

    cdef int AV_DICT_IGNORE_SUFFIX

    cdef AVDictionaryEntry* av_dict_get(
        AVDictionary *dict,
        char *key,
        AVDictionaryEntry *prev,
        int flags,
    )

    cdef int av_dict_set(
        AVDictionary **pm,
        const char *key,
        const char *value,
        int flags
    )

    cdef int av_dict_count(
        AVDictionary *m
    )

    cdef int av_dict_copy(
        AVDictionary **dst,
        AVDictionary *src,
        int flags
    )
