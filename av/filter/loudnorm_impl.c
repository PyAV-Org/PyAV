#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavfilter/avfilter.h>
#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <string.h>

#ifdef _WIN32
    #include <windows.h>
#else
    #include <pthread.h>
#endif

#ifdef _WIN32
    static CRITICAL_SECTION json_mutex;
    static CONDITION_VARIABLE json_cond;
    static int mutex_initialized = 0;
#else
    static pthread_mutex_t json_mutex = PTHREAD_MUTEX_INITIALIZER;
    static pthread_cond_t json_cond = PTHREAD_COND_INITIALIZER;
#endif

static char json_buffer[2048] = {0};
static int json_captured = 0;

// Custom logging callback
static void logging_callback(void *ptr, int level, const char *fmt, va_list vl) {
    char line[2048];
    vsnprintf(line, sizeof(line), fmt, vl);

    const char *json_start = strstr(line, "{");
    if (json_start) {
        #ifdef _WIN32
        EnterCriticalSection(&json_mutex);
        #else
        pthread_mutex_lock(&json_mutex);
        #endif

        strncpy(json_buffer, json_start, sizeof(json_buffer) - 1);
        json_captured = 1;

        #ifdef _WIN32
        WakeConditionVariable(&json_cond);
        LeaveCriticalSection(&json_mutex);
        #else
        pthread_cond_signal(&json_cond);
        pthread_mutex_unlock(&json_mutex);
        #endif
    }
}

char* loudnorm_get_stats(
    AVFormatContext* fmt_ctx,
    int audio_stream_index,
    const char* loudnorm_args
) {
    char* result = NULL;
    json_captured = 0;    // Reset the captured flag
    memset(json_buffer, 0, sizeof(json_buffer));  // Clear the buffer

    #ifdef _WIN32
    // Initialize synchronization objects if needed
    if (!mutex_initialized) {
        InitializeCriticalSection(&json_mutex);
        InitializeConditionVariable(&json_cond);
        mutex_initialized = 1;
    }
    #endif

    av_log_set_callback(logging_callback);

    AVFilterGraph *filter_graph = NULL;
    AVFilterContext *src_ctx = NULL, *sink_ctx = NULL, *loudnorm_ctx = NULL;

    AVCodec *codec = NULL;
    AVCodecContext *codec_ctx = NULL;
    int ret;

    AVCodecParameters *codecpar = fmt_ctx->streams[audio_stream_index]->codecpar;
    codec = (AVCodec *)avcodec_find_decoder(codecpar->codec_id);
    codec_ctx = avcodec_alloc_context3(codec);
    avcodec_parameters_to_context(codec_ctx, codecpar);
    avcodec_open2(codec_ctx, codec, NULL);

    char ch_layout_str[64];
    av_channel_layout_describe(&codecpar->ch_layout, ch_layout_str, sizeof(ch_layout_str));

    filter_graph = avfilter_graph_alloc();

    char args[512];
    snprintf(args, sizeof(args),
        "time_base=%d/%d:sample_rate=%d:sample_fmt=%s:channel_layout=%s",
        fmt_ctx->streams[audio_stream_index]->time_base.num,
        fmt_ctx->streams[audio_stream_index]->time_base.den,
        codecpar->sample_rate,
        av_get_sample_fmt_name(codec_ctx->sample_fmt),
        ch_layout_str);

    avfilter_graph_create_filter(&src_ctx, avfilter_get_by_name("abuffer"),
        "src", args, NULL, filter_graph);
    avfilter_graph_create_filter(&sink_ctx, avfilter_get_by_name("abuffersink"),
        "sink", NULL, NULL, filter_graph);
    avfilter_graph_create_filter(&loudnorm_ctx, avfilter_get_by_name("loudnorm"),
        "loudnorm", loudnorm_args, NULL, filter_graph);

    avfilter_link(src_ctx, 0, loudnorm_ctx, 0);
    avfilter_link(loudnorm_ctx, 0, sink_ctx, 0);
    avfilter_graph_config(filter_graph, NULL);

    AVPacket *packet = av_packet_alloc();
    AVFrame *frame = av_frame_alloc();
    AVFrame *filt_frame = av_frame_alloc();

    while ((ret = av_read_frame(fmt_ctx, packet)) >= 0) {
        if (packet->stream_index != audio_stream_index) {
            av_packet_unref(packet);
            continue;
        }

        ret = avcodec_send_packet(codec_ctx, packet);
        if (ret < 0) {
            av_packet_unref(packet);
            continue;
        }

        while (ret >= 0) {
            ret = avcodec_receive_frame(codec_ctx, frame);
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
            if (ret < 0) goto end;

            ret = av_buffersrc_add_frame_flags(src_ctx, frame, AV_BUFFERSRC_FLAG_KEEP_REF);
            if (ret < 0) goto end;

            while (1) {
                ret = av_buffersink_get_frame(sink_ctx, filt_frame);
                if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
                if (ret < 0) goto end;
                av_frame_unref(filt_frame);
            }
        }
        av_packet_unref(packet);
    }

    // Flush decoder
    avcodec_send_packet(codec_ctx, NULL);
    while (avcodec_receive_frame(codec_ctx, frame) >= 0) {
        ret = av_buffersrc_add_frame(src_ctx, frame);
        if (ret < 0) goto end;
    }

    // Flush filter
    ret = av_buffersrc_add_frame(src_ctx, NULL);
    if (ret < 0) goto end;
    while (av_buffersink_get_frame(sink_ctx, filt_frame) >= 0) {
        av_frame_unref(filt_frame);
    }

    // Pushes graph
    avfilter_graph_free(&filter_graph);

end:
    avcodec_free_context(&codec_ctx);
    avformat_close_input(&fmt_ctx);
    av_frame_free(&filt_frame);
    av_frame_free(&frame);
    av_packet_free(&packet);

    #ifdef _WIN32
    EnterCriticalSection(&json_mutex);
    while (!json_captured) {
        if (!SleepConditionVariableCS(&json_cond, &json_mutex, 5000)) { // 5 second timeout
            fprintf(stderr, "Timeout waiting for JSON data\n");
            break;
        }
    }
    if (json_captured) {
        result = _strdup(json_buffer);  // Use _strdup on Windows
    }
    LeaveCriticalSection(&json_mutex);
    #else
    struct timespec timeout;
    clock_gettime(CLOCK_REALTIME, &timeout);
    timeout.tv_sec += 5;  // 5 second timeout

    pthread_mutex_lock(&json_mutex);
    while (json_captured == 0) {
        int ret = pthread_cond_timedwait(&json_cond, &json_mutex, &timeout);
        if (ret == ETIMEDOUT) {
            fprintf(stderr, "Timeout waiting for JSON data\n");
            break;
        }
    }
    if (json_captured) {
        result = strdup(json_buffer);
    }
    pthread_mutex_unlock(&json_mutex);
    #endif

    av_log_set_callback(av_log_default_callback);
    return result;
}
