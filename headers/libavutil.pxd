from libc.stdint cimport int64_t, uint8_t, uint64_t

cdef extern from "libavutil_compat.h":
    pass

cdef extern from "libavutil/mathematics.h":
    pass

cdef extern from "libavutil/avutil.h":

    cdef enum AVPixelFormat:
        AV_PIX_FMT_NONE
        AV_PIX_FMT_YUV420P
        AV_PIX_FMT_RGB24
        PIX_FMT_RGB24
        PIX_FMT_RGBA
        
    cdef enum AVSampleFormat:
        AV_SAMPLE_FMT_NONE
        AV_SAMPLE_FMT_S16
        AV_SAMPLE_FMT_FLTP
        
    cdef enum AVRounding:
        AV_ROUND_ZERO
        AV_ROUND_INF
        AV_ROUND_DOWN
        AV_ROUND_UP
        AV_ROUND_NEAR_INF
        AV_ROUND_PASS_MINMAX
    
    cdef int AV_ERROR_MAX_STRING_SIZE
    cdef int AVERROR_EOF
    
    cdef int AV_CH_LAYOUT_STEREO
    
    cdef int ENOMEM
    
    cdef int EAGAIN
    
    cdef double M_PI
    
    cdef int AVERROR(int error)
    cdef int av_strerror(int errno, char *output, size_t output_size)
    cdef char* av_err2str(int errnum)

    cdef void* av_malloc(size_t size)
    cdef void *av_calloc(size_t nmemb, size_t size)
    
    cdef void av_free(void* ptr)
    cdef void av_freep(void *ptr)
    
    cdef int av_get_bytes_per_sample(AVSampleFormat sample_fmt)
    
    cdef int av_samples_get_buffer_size(
        int *linesize,
        int nb_channels,
        int nb_samples,
        AVSampleFormat sample_fmt,
        int align
    )

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
    
    # See: http://ffmpeg.org/doxygen/trunk/structAVRational.html
    ctypedef struct AVRational:
        int num
        int den
        
    cdef AVRational AV_TIME_BASE_Q
    
    # Rescales from one time base to another
    cdef int64_t av_rescale_q(
        int64_t a, # time stamp
        AVRational bq, # source time base
        AVRational cq  # target time base
    )
    
    # Rescale a 64-bit integer with specified rounding.
    # A simple a*b/c isn't possible as it can overflow
    cdef int64_t av_rescale_rnd(
        int64_t a,
        int64_t b, 
        int64_t c,
        AVRounding r
    )
    
    cdef int64_t av_rescale(
        int64_t a, 
        int64_t b, 
        int64_t c
    )
    
    cdef char* av_strdup(char *s)
    
    cdef int av_opt_set_int(
        void *obj,
        char *name,
        int64_t value,
        int search_flags
    )

cdef extern from "libavutil/pixdesc.h":
    cdef char * av_get_pix_fmt_name(AVPixelFormat pix_fmt)
    cdef AVPixelFormat av_get_pix_fmt(char* name)

cdef extern from "libavutil/samplefmt.h":
    cdef char * av_get_sample_fmt_name(AVSampleFormat sample_fmt)
    cdef AVSampleFormat av_get_sample_fmt(char* name)
    
    cdef int av_sample_fmt_is_planar(AVSampleFormat sample_fmt)
    
    cdef int av_samples_alloc(
        uint8_t** audio_data,
        int* linesize,
        int nb_channels,
        int nb_samples,
        AVSampleFormat sample_fmt,
        int align
    )
    
    cdef int av_samples_get_buffer_size(
        int *linesize,
        int nb_channels,
        int nb_samples,
        AVSampleFormat sample_fmt,
        int align
    )
    
    cdef int av_samples_set_silence(
        uint8_t **audio_data,
        int offset,
        int nb_samples,
        int nb_channels,
        AVSampleFormat sample_fmt
     )
        
    
cdef extern from "libavutil/audioconvert.h":
    cdef char* av_get_channel_name(uint64_t channel)
    
    cdef uint64_t av_get_channel_layout(char* name)
    
    cdef int av_get_channel_layout_nb_channels(uint64_t channel_layout)
    
    # Returns default channel layout for a given number of channels
    cdef int64_t av_get_default_channel_layout(int nb_channels)
    
    cdef void av_get_channel_layout_string(
        char* buff,
        int buf_size,
        int nb_channels,
        uint64_t channel_layout
    )
    
    
cdef extern from "libavutil/audio_fifo.h":
    
    cdef struct AVAudioFifo:
        pass
    
    cdef void av_audio_fifo_free(AVAudioFifo *af)
    
    cdef AVAudioFifo* av_audio_fifo_alloc(
         AVSampleFormat sample_fmt,
         int channels,
         int nb_samples
    )
    
    cdef int av_audio_fifo_write(
        AVAudioFifo *af, 
        void **data, 
        int nb_samples
    )
    
    cdef int av_audio_fifo_read(
        AVAudioFifo *af,
        void **data, 
        int nb_samples
    )
    
    cdef int av_audio_fifo_size(AVAudioFifo *af)
    cdef int av_audio_fifo_space (AVAudioFifo *af)
    
