cdef extern from "libavutil/error.h" nogil:

    # Not actually from here, but whatever.
    cdef int ENOMEM
    cdef int EAGAIN

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

    cdef int AVERROR_NOMEM "AVERROR(ENOMEM)"

    # cdef int FFERRTAG(int, int, int, int)

    cdef int AVERROR(int error)

    cdef int AV_ERROR_MAX_STRING_SIZE

    cdef int av_strerror(int errno, char *output, size_t output_size)
    cdef char* av_err2str(int errnum)
