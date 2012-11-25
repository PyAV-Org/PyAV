import os

cimport libav as lib
from .utils import LibError
from .utils cimport err_check





def iter_frames(argv):
    
    print 'Starting.'
    
    cdef lib.AVFormatContext *format_ctx = NULL
    cdef int video_stream_i = 0
    cdef int i = 0
    cdef lib.AVCodecContext *codec_ctx = NULL
    cdef lib.AVCodec *codec = NULL
    cdef lib.AVDictionary *options = NULL
    
    if len(argv) < 2:
        print 'usage: tutorial <movie>'
        exit(1)
    filename = os.path.abspath(argv[1])
    
    print 'Registering codecs.'
    lib.av_register_all()
        
    print 'Opening', repr(filename)
    err_check(lib.avformat_open_input(&format_ctx, filename, NULL, NULL))
    
    print 'Getting stream info.'
    err_check(lib.avformat_find_stream_info(format_ctx, NULL))
    
    print 'Dumping to stderr.'
    lib.av_dump_format(format_ctx, 0, filename, 0)
    
    print format_ctx.nb_streams, 'streams.'
    print 'Finding first video stream...'
    for i in range(format_ctx.nb_streams):
        if format_ctx.streams[i].codec.codec_type == lib.AVMEDIA_TYPE_VIDEO:
            video_stream_i = i
            codec_ctx = format_ctx.streams[video_stream_i].codec
            print '\tfound %r at %d' % (codec_ctx.codec_name, video_stream_i)
            break
    else:
        print 'Could not find video stream.'
        return
    
    # Find the decoder for the video stream.
    codec = lib.avcodec_find_decoder(codec_ctx.codec_id)
    if codec == NULL:
        print 'Unsupported codec!'
        return
    print 'Codec is %r (%r)' % (codec.name, codec.long_name)
    
    print '"Opening" the codec.'
    err_check(lib.avcodec_open2(codec_ctx, codec, &options))
    
    print 'Allocating frames.'
    cdef lib.AVFrame *raw_frame = lib.avcodec_alloc_frame()
    cdef lib.AVFrame *rgb_frame = lib.avcodec_alloc_frame()
    if raw_frame == NULL or rgb_frame == NULL:
        print 'Could not allocate frames.'
        return
    
    print 'Allocating buffer...'
    cdef int buffer_size = lib.avpicture_get_size(
        lib.PIX_FMT_RGBA,
        codec_ctx.width,
        codec_ctx.height,
    )
    print '\tof', buffer_size, 'bytes'
    cdef unsigned char *buffer = <unsigned char *>lib.av_malloc(buffer_size * sizeof(char))
    
    print 'Allocating SwsContext'
    cdef lib.SwsContext *sws_ctx = lib.sws_getContext(
        codec_ctx.width,
        codec_ctx.height,
        codec_ctx.pix_fmt,
        codec_ctx.width,
        codec_ctx.height,
        lib.PIX_FMT_RGBA,
        lib.SWS_BILINEAR,
        NULL,
        NULL,
        NULL
    )
    if sws_ctx == NULL:
        print 'Could not allocate.'
        return
     
    # Assign appropriate parts of buffer to image planes in pFrameRGB
    # Note that pFrameRGB is an AVFrame, but AVFrame is a superset
    # of AVPicture
    print 'Assigning buffer.'
    lib.avpicture_fill(
        <lib.AVPicture *>rgb_frame,
        buffer,
        lib.PIX_FMT_RGBA,
        codec_ctx.width,
        codec_ctx.height
    )
    
    print 'Reading packets...'
    cdef lib.AVPacket packet
    cdef int frame_i = 0
    cdef bint finished = False
    while True:
        
        try:
            err_check(lib.av_read_frame(format_ctx, &packet))
        except LibError:
            break
        
        # Is it from the right stream?
        # print '\tindex_stream', packet.stream_index
        if packet.stream_index != video_stream_i:
            continue
        
        # Decode the frame.
        err_check(lib.avcodec_decode_video2(codec_ctx, raw_frame, &finished, &packet))
        if not finished:
            continue
        
        frame_i += 1
        # print '\t', frame_i
        
        lib.sws_scale(
            sws_ctx,
            raw_frame.data,
            raw_frame.linesize,
            0, # slice Y
            codec_ctx.height,
            rgb_frame.data,
            rgb_frame.linesize,
        )
        
        # Save the frame.
        # print raw_frame.linesize[0]
        # print raw_frame.width
        # print raw_frame.height
        
        # Create a Python buffer object so PIL doesn't need to copy the image.
        yield lib.PyBuffer_FromMemory(rgb_frame.data[0], buffer_size)
        
        lib.av_free_packet(&packet)
    
    # Free the RGB image.
    lib.av_free(buffer)
    lib.av_free(rgb_frame)
    lib.av_free(raw_frame)

    # Close the codec.
    lib.avcodec_close(codec_ctx);

    # Close the video file.
    lib.avformat_close_input(&format_ctx);
        
    print 'Done.'


