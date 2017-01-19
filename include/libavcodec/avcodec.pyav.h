#include "libavcodec/avcodec.h"

#ifndef PYAV_HAVE_AV_FRAME_GET_BEST_EFFORT_TIMESTAMP

    int64_t av_frame_get_best_effort_timestamp(const AVFrame *frame) 
    {
        // TODO: do this right.
        return frame->pkt_pts;
    }

#endif

#ifndef PYAV_HAVE_AVCODEC_FREE_CONTEXT
    void avcodec_free_context(AVCodecContext **pavctx)
    {
        AVCodecContext *avctx = *pavctx;

        if (!avctx)
            return;

        avcodec_close(avctx);

        av_freep(&avctx->extradata);
        av_freep(&avctx->subtitle_header);

        av_freep(pavctx);
    }
#endif

#ifdef PYAV_HAVE_FFMPEG

    #define AVPixelFormat PixelFormat
    #define AV_PIX_FMT_YUV420P PIX_FMT_YUV420P

#endif


// Some of these properties don't exist in both FFMpeg and LibAV, so we
// signal to our code that they are missing via 0.
#ifndef AV_CODEC_PROP_INTRA_ONLY
    #define AV_CODEC_PROP_INTRA_ONLY 0
#endif
#ifndef AV_CODEC_PROP_LOSSY
    #define AV_CODEC_PROP_LOSSY 0
#endif
#ifndef AV_CODEC_PROP_LOSSLESS
    #define AV_CODEC_PROP_LOSSLESS 0
#endif
#ifndef AV_CODEC_PROP_REORDER
    #define AV_CODEC_PROP_REORDER 0
#endif
#ifndef AV_CODEC_PROP_BITMAP_SUB
    #define AV_CODEC_PROP_BITMAP_SUB 0
#endif
#ifndef AV_CODEC_PROP_TEXT_SUB
    #define AV_CODEC_PROP_TEXT_SUB 0
#endif

#ifndef CODEC_CAP_DRAW_HORIZ_BAND
    #define CODEC_CAP_DRAW_HORIZ_BAND 0
#endif
#ifndef CODEC_CAP_DR1
    #define CODEC_CAP_DR1 0
#endif
#ifndef CODEC_CAP_TRUNCATED
    #define CODEC_CAP_TRUNCATED 0
#endif
#ifndef CODEC_CAP_HWACCEL
    #define CODEC_CAP_HWACCEL 0
#endif
#ifndef CODEC_CAP_DELAY
    #define CODEC_CAP_DELAY 0
#endif
#ifndef CODEC_CAP_SMALL_LAST_FRAME
    #define CODEC_CAP_SMALL_LAST_FRAME 0
#endif
#ifndef CODEC_CAP_HWACCEL_VDPAU
    #define CODEC_CAP_HWACCEL_VDPAU 0
#endif
#ifndef CODEC_CAP_SUBFRAMES
    #define CODEC_CAP_SUBFRAMES 0
#endif
#ifndef CODEC_CAP_EXPERIMENTAL
    #define CODEC_CAP_EXPERIMENTAL 0
#endif
#ifndef CODEC_CAP_CHANNEL_CONF
    #define CODEC_CAP_CHANNEL_CONF 0
#endif
#ifndef CODEC_CAP_NEG_LINESIZES
    #define CODEC_CAP_NEG_LINESIZES 0
#endif
#ifndef CODEC_CAP_FRAME_THREADS
    #define CODEC_CAP_FRAME_THREADS 0
#endif
#ifndef CODEC_CAP_SLICE_THREADS
    #define CODEC_CAP_SLICE_THREADS 0
#endif
#ifndef CODEC_CAP_PARAM_CHANGE
    #define CODEC_CAP_PARAM_CHANGE 0
#endif
#ifndef CODEC_CAP_AUTO_THREADS
    #define CODEC_CAP_AUTO_THREADS 0
#endif
#ifndef CODEC_CAP_VARIABLE_FRAME_SIZE
    #define CODEC_CAP_VARIABLE_FRAME_SIZE 0
#endif
#ifndef CODEC_CAP_INTRA_ONLY
    #define CODEC_CAP_INTRA_ONLY 0
#endif
#ifndef CODEC_CAP_LOSSLESS
    #define CODEC_CAP_LOSSLESS 0
#endif
