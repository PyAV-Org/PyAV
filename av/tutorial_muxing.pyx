from libc.stdint cimport int16_t,int64_t,uint8_t
from libc.math cimport sin

cimport libav as lib

STREAM_FRAME_RATE = 25
STREAM_PIX_FMT = lib.AV_PIX_FMT_YUV420P
STREAM_DURATION = 20
STREAM_NB_FRAMES = int(STREAM_DURATION * STREAM_FRAME_RATE)

cdef lib.AVFrame *frame

#Video Stuff

cdef int frame_count = 0

cdef lib.AVPicture src_picture
cdef lib.AVPicture dst_picture

cdef int sws_flags = lib.SWS_BICUBIC

#Audio Stuff
cdef float t, tincr, tincr2

cdef int16_t *samples
cdef int audio_input_frame_size


cdef lib.AVStream* add_stream(lib.AVFormatContext *oc, lib.AVCodec **codec, lib.AVCodecID codec_id):
    
    
    print "adding stream",lib.avcodec_get_name(codec_id), codec_id
    
    cdef lib.AVCodecContext *c
    cdef lib.AVStream *st
    
    codec[0] = lib.avcodec_find_encoder(codec_id)
    
    if not codec[0]:
        raise Exception("could not find encoder")
    
    st = lib.avformat_new_stream(oc,codec[0])
    
    if not st:
        raise Exception("Could not allocate stream")
    
    st.id = oc.nb_streams -1
    c = st.codec

    if codec[0].type == lib.AVMEDIA_TYPE_AUDIO:
        print "audio stream"
        st.id = 1
        c.sample_fmt = lib.AV_SAMPLE_FMT_S16
        
        c.bit_rate = 64000
        c.sample_rate = 44100
        c.channels = 2
        c.channel_layout = lib.AV_CH_LAYOUT_STEREO
        
    elif codec[0].type == lib.AVMEDIA_TYPE_VIDEO:
        print "video stream"
        c.codec_id = codec_id
        c.bit_rate = 400000
        #Resolution must be a multiple of two
        c.width = 352
        c.height = 288
        c.time_base.den = STREAM_FRAME_RATE
        c.time_base.num = 1
        c.gop_size = 12 #emit one intra frame every twelve frames at most
        
        c.pix_fmt = lib.AV_PIX_FMT_YUV420P

        if c.codec_id == lib.AV_CODEC_ID_MPEG2VIDEO:
            print "setting max_b_frames 2"
            c.max_b_frames = 2
        if c.codec_id == lib.AV_CODEC_ID_MPEG1VIDEO:
            print "setting mb_decision 2"
            c.mb_decision = 2
        
    #Some formats want stream headers to be separate
    if oc.oformat.flags & lib.AVFMT_GLOBALHEADER:
        print "formats wants stream headers to be separate"
        c.flags |= lib.CODEC_FLAG_GLOBAL_HEADER
        
    return st

cdef open_video(lib.AVFormatContext *oc, lib.AVCodec *codec, lib.AVStream *st):
    print "opening video"
    cdef lib.AVCodecContext *c = st.codec
    
    global frame
    global dst_picture
    global src_picture
    
    ret = lib.avcodec_open2(c, codec, NULL)
    if ret <0:
        raise Exception("Could not open video codec: %s" % lib.av_err2str(ret))
    
    print "allocate frame"
    frame = lib.avcodec_alloc_frame()
    
    if not frame:
        raise Exception("Could not allocate video frame")
    
    print "Allocate the encoded raw picture"
    ret = lib.avpicture_alloc(&dst_picture, c.pix_fmt, c.width, c.height)
    
    if ret < 0:
        raise Exception("Could not allocate picture: %s" % lib.av_err2str(ret))
    
    # If the output format is not YUV420P, then a temporary YUV420P
    # picture is needed too. It is then converted to the required
    # output format
    
    if not c.pix_fmt == lib.AV_PIX_FMT_YUV420P:
        print "allocate temporary picture"
        ret = lib.avpicture_alloc(&src_picture, lib.AV_PIX_FMT_YUV420P, c.width, c.height)
        if ret < 0:
            raise Exception("Could not allocate temporary picture: %s" % lib.av_err2str(ret))
        
    # copy data and linesize picture pointers to frame 
    f = < lib.AVPicture*> frame
    f[0] = dst_picture
    
    
cdef write_video_frame(lib.AVFormatContext *oc, lib.AVStream *st):
    print 'writing video frame'
    cdef int ret
    cdef lib.SwsContext *sws_ctx
    
    cdef lib.AVCodecContext *c = st.codec
    
    cdef lib.AVPacket pkt
    
    cdef int got_output
    
    global frame
    
    global frame_count
    global src_picture
    global dst_picture
    
    if frame_count >= STREAM_NB_FRAMES:
        pass
    
    else:
        
        if c.pix_fmt != lib.AV_PIX_FMT_YUV420P:
            
            if sws_ctx == NULL:
                print "sws NULL"
                sws_ctx = lib.sws_getContext(c.width, c.height, lib.AV_PIX_FMT_YUV420P,
                                         c.width, c.height, c.pix_fmt,
                                         sws_flags, NULL, NULL, NULL)
                if sws_ctx == NULL:
                    raise Exception("Could not initialize the conversion context")
                
                fill_yuv_image(&src_picture, frame_count, c.width,c.height)
        else:
            fill_yuv_image(&dst_picture, frame_count, c.width,c.height)
        
    if oc.oformat.flags & lib.AVFMT_RAWPICTURE:
        print "using raw picture"
        # Raw video case - directly store the picture in the packet
        lib.av_init_packet(&pkt)
        
        pkt.flags |= lib.AV_PKT_FLAG_KEY
        pkt.stream_index = st.index
        pkt.data = dst_picture.data[0]
        pkt.size = sizeof(lib.AVPicture)
        
        ret = lib.av_interleaved_write_frame(oc, &pkt)
        
    else:
        # encode the image
        lib.av_init_packet(&pkt)
        pkt.data = NULL #packet data will be allocated by the encoder
        pkt.size = 0
        
        print "encoding video"
        ret = lib.avcodec_encode_video2(c, &pkt, frame, &got_output)
        
        if ret <0:
            raise Exception("Error encoding video frame: %s" % lib.av_err2str(ret))
        
        # If size is zeror, it means the image was buffered
        if got_output:
            print "got output"
            
            if c.coded_frame.key_frame:
                pkt.flags |= lib.AV_PKT_FLAG_KEY
            
            pkt.stream_index = st.index
            print "Writing the compressed video frame to the media file"
            ret = lib.av_interleaved_write_frame(oc, &pkt)
            print "frame interleaved"
        else:
            print "buffered frame",frame_count
            ret = 0
    
    if ret != 0:
        raise Exception("Error while writing video frame: %s" % lib.av_err2str(ret))    
    frame_count += 1

                
cdef fill_yuv_image(lib.AVPicture *pict, int frame_index, int width, int height):
    
    cdef int x,y,i
    
    i = frame_index
    
    #Y
    for y in range(height):
        for x in range(width):
            pict.data[0][y * pict.linesize[0] + x] = x + y + i * 3
            
    # Cb and Cr
    for y in range(height / 2 ):
        for x in range(width / 2):
            pict.data[1][y * pict.linesize[1] + x] = 128 + y + i * 2
            pict.data[2][y * pict.linesize[2] + x] = 64 + x + i * 2

cdef close_video(lib.AVFormatContext *oc, lib.AVStream *st):
    
    global frame
    global src_picture
    global dst_picture
    
    lib.avcodec_close(st.codec)
    lib.av_free(src_picture.data[0])
    lib.av_free(dst_picture.data[0])
    lib.av_free(frame)
    
cdef close_audio(lib.AVFormatContext *oc, lib.AVStream *st):

    global samples
    lib.avcodec_close(st.codec)
    lib.av_free(samples)
    
    

cdef open_audio(lib.AVFormatContext *oc, lib.AVCodec *codec, lib.AVStream *st):
    
    print "opening audio"
    
    global samples
    global audio_input_frame_size
    global t
    global tincr
    global tincr2
    
    cdef lib.AVCodecContext *c = st.codec
    
    ret = lib.avcodec_open2(c, codec, NULL)
    if ret <0:
        raise Exception("Could not open video codec: %s" % lib.av_err2str(ret))
    
    print "init signal generator"
    t = 0
    
    tincr = 2 * lib.M_PI * 110.0 / c.sample_rate
    
    # increment frequency by 110 Hz per second
    tincr2 = 2 * lib.M_PI * 110.0 / c.sample_rate / c.sample_rate
    
    if c.codec.capabilities & lib.CODEC_CAP_VARIABLE_FRAME_SIZE:
        print "audio_input_frame_size capabilities CODEC_CAP_VARIABLE_FRAME_SIZE, 10000"
        audio_input_frame_size = 10000
    else:
        print "audio_input_frame_size using codec frame size", c.frame_size
        audio_input_frame_size = c.frame_size

    print "tincr =", tincr
    print "tincr2 =", tincr2
    print "audio_input_frame_size =",audio_input_frame_size

    samples = <int16_t *>lib.av_malloc(audio_input_frame_size * lib.av_get_bytes_per_sample(c.sample_fmt) * c.channels)
    if not samples:
        raise Exception("could not allocate audio samples buffer")
    
cdef write_audio_frame(lib.AVFormatContext *oc, lib.AVStream *st):

    cdef lib.AVCodecContext *c = st.codec
    cdef int got_packet, ret
    global samples
    global audio_input_frame_size
    
    cdef lib.AVPacket pkt
    lib.av_init_packet(&pkt)
    #data and size must be 0
    pkt.size = 0
    pkt.data = NULL

    
    
    cdef lib.AVFrame *audio_frame = lib.avcodec_alloc_frame()
    
    print audio_input_frame_size,c.frame_size
    
    print "sample count should be =", audio_input_frame_size * c.channels, c.frame_size*c.channels
    get_audio_frame(samples, audio_input_frame_size, c.channels)

    audio_frame.nb_samples = audio_input_frame_size
    audio_frame.format         = c.sample_fmt;
    audio_frame.channel_layout = c.channel_layout

    #frame.format = c.sample_fmt
    #frame.channel_layout = c.channel_layout
    
    
    lib.avcodec_fill_audio_frame(audio_frame,
                                 c.channels,
                                 c.sample_fmt,
                                 <uint8_t *> samples,
                                 audio_input_frame_size * lib.av_get_bytes_per_sample(c.sample_fmt) * c.channels,
                                 1)
    
    
    #print "audio buffer filled", ret
    print "encoding audio"
    ret = lib.avcodec_encode_audio2(c, &pkt, audio_frame, &got_packet)
    if ret < 0:
        raise Exception("Error encoding audio frame: %s" % lib.av_err2str(ret))
    
    if not got_packet:
        print "didn't get packet"
        return
    
    pkt.stream_index = st.index
    
    print "Writing the compressed audio frame to the media file"
    
    ret = lib.av_interleaved_write_frame(oc, &pkt)
    print "Wrote audio data"
    if ret != 0:
        raise Exception("Error while writing audio frame: %s\n" % lib.av_err2str(ret))
    
    
    lib.avcodec_free_frame(&audio_frame)
    
cdef get_audio_frame(int16_t *samples, int frame_size, int nb_channels):
    
    cdef int j, i, v
    
    cdef int16_t *q
    cdef int step = 0
    
    global t
    global tincr
    global tincr2
    q = samples
    
    for j in range(frame_size):
        v = <int > (sin(t) * 10000)
        
        for i in range(nb_channels):
            q[step] = v
            step += 1
            t +=  tincr
            tincr += tincr2
    
    print "samples count =", step

    

    
def main():
    
    filename = "out.mpg"
    cdef lib.AVOutputFormat *fmt
    cdef lib.AVFormatContext *oc
    
    cdef lib.AVStream *audio_st
    cdef lib.AVStream *video_st
    
    cdef lib.AVCodec *audio_codec
    cdef lib.AVCodec *video_codec
    cdef int64_t pts_step
    
    global frame
    
    lib.avformat_alloc_output_context2(&oc, NULL,NULL, filename)
    
    if not oc:
        raise Exception( "Could not deduce output format")
        
    
    fmt = oc.oformat
    # Add the audio and video streams using the default format codecs
    # and initialize the codecs
    
    video_st = NULL
    audio_st = NULL
    
    if fmt.video_codec != lib.AV_CODEC_ID_NONE:
        video_st = add_stream(oc, &video_codec,fmt.video_codec)
        
    if fmt.audio_codec != lib.AV_CODEC_ID_NONE:
        audio_st = add_stream(oc, &audio_codec, fmt.audio_codec)
        
    # Now that all the parameters are set, we can open the audio and
    # video codecs and allocate the necessary encode buffers.
    
    if video_st:
        open_video(oc, video_codec, video_st)
    if audio_st:
        open_audio(oc, audio_codec, audio_st)
                
    lib.av_dump_format(oc, 0, filename, 1)
    
    #if fmt.flags & lib.AVFMT_NOFILE:
    print "need to open out file"
    ret = lib.avio_open(&oc.pb, filename, lib.AVIO_FLAG_WRITE)
    if ret <0:
        raise Exception("Could not open '%s' %s" % (filename,lib.av_err2str(ret)))
    
    
    print "writing header"
    ret = lib.avformat_write_header(oc, NULL)
    print ret
    
    if ret < 0:
        raise Exception("Error occurred when opening output file: %s" %  lib.av_err2str(ret))
    
    
    if frame:
        frame.pts = 0
    
    while True:
        # Compute current audio and video time

        if audio_st:
            audio_pts = <double >(audio_st.pts.val) * audio_st.time_base.num / audio_st.time_base.den
        else:
            audio_pts = 0.0
        if video_st:
            video_pts = <double > (video_st.pts.val) * video_st.time_base.num / video_st.time_base.den
        else:
            video_pts = 0.0
        
        print "**pts audio:", audio_pts,"pts video:", video_pts, "dur:",STREAM_DURATION
        
        if (not audio_st or audio_pts >= STREAM_DURATION) and (not video_st or video_pts >= STREAM_DURATION):
            print "end of stream"
            break
        
        if not video_st or (video_st and audio_st and audio_pts < video_pts):
            write_audio_frame(oc, audio_st)
            
            #raise Exception("Stop!")
        
        else:
            write_video_frame(oc, video_st)
            print "frame written"

            pts_step = lib.av_rescale_q(1, video_st.codec.time_base, video_st.time_base)
            
            print "pts_step", pts_step
            frame.pts += pts_step
            
            print "frame pts", frame.pts
    
    # Write the trailer, if any. The trailer must be written before you
    # close the CodecContexts open when you wrote the header; otherwise
    # av_write_trailer() may try to use memory that was freed on
    # av_codec_close().
    print "writing trailer"
    lib.av_write_trailer(oc)
    
    # Close each codec.
    
    if video_st:
        close_video(oc, video_st)
    
    if audio_st:
        close_audio(oc, video_st)

    lib.avio_close(oc.pb)
    
    # free the stream
    lib.avformat_free_context(oc)

        #video_st = 