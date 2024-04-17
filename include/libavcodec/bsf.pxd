
cdef extern from "libavcodec/bsf.h" nogil:

    cdef struct AVBitStreamFilter:
        const char *name
        AVCodecID *codec_ids

    cdef struct AVCodecParameters:
        pass

    cdef struct AVBSFContext:
        const AVBitStreamFilter *filter
        const AVCodecParameters *par_in
        const AVCodecParameters *par_out

    cdef const AVBitStreamFilter* av_bsf_get_by_name(const char *name)

    cdef int av_bsf_list_parse_str(
        const char *str,
        AVBSFContext **bsf
    )

    cdef int av_bsf_init(AVBSFContext *ctx)
    cdef void av_bsf_free(AVBSFContext **ctx)

    cdef AVBitStreamFilter* av_bsf_iterate(void **opaque)

    cdef int av_bsf_send_packet(
        AVBSFContext *ctx,
        AVPacket *pkt
    )

    cdef int av_bsf_receive_packet(
        AVBSFContext *ctx,
        AVPacket *pkt
    )

    cdef void av_bsf_flush(
        AVBSFContext *ctx
    )
