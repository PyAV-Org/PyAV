from libc.stdint cimport int64_t, uint8_t, uint64_t

cimport libav as lib


cdef extern from "libavutil/error.h" nogil:
    cdef int AVERROR_BSF_NOT_FOUND
    cdef int AVERROR_BUG
    cdef int AVERROR_BUFFER_TOO_SMALL
    cdef int AVERROR_DECODER_NOT_FOUND
    cdef int AVERROR_DEMUXER_NOT_FOUND
    cdef int AVERROR_ENCODER_NOT_FOUND
    cdef int AVERROR_EOF
    cdef int AVERROR_EXIT
    cdef int AVERROR_EXTERNAL
    cdef int AVERROR_FILTER_NOT_FOUND
    cdef int AVERROR_INVALIDDATA
    cdef int AVERROR_MUXER_NOT_FOUND
    cdef int AVERROR_OPTION_NOT_FOUND
    cdef int AVERROR_PATCHWELCOME
    cdef int AVERROR_PROTOCOL_NOT_FOUND
    cdef int AVERROR_UNKNOWN
    cdef int AVERROR_EXPERIMENTAL
    cdef int AVERROR_INPUT_CHANGED
    cdef int AVERROR_OUTPUT_CHANGED
    cdef int AVERROR_HTTP_BAD_REQUEST
    cdef int AVERROR_HTTP_UNAUTHORIZED
    cdef int AVERROR_HTTP_FORBIDDEN
    cdef int AVERROR_HTTP_NOT_FOUND
    cdef int AVERROR_HTTP_OTHER_4XX
    cdef int AVERROR_HTTP_SERVER_ERROR

cdef int stash_exception(exc_info=*)

cpdef int err_check(int res=*, filename=*) except -1


cdef dict avdict_to_dict(lib.AVDictionary *input, str encoding=*, str errors=*)
cdef dict_to_avdict(lib.AVDictionary **dst, dict src, bint clear=*, str encoding=*, str errors=*)


cdef object avrational_to_fraction(const lib.AVRational *input)
cdef object to_avrational(object value, lib.AVRational *input)


cdef flag_in_bitfield(uint64_t bitfield, uint64_t flag)
