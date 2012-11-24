import os

cimport libav as C


class LibError(ValueError):
    pass


cdef int errcheck(int res) except -1:
    cdef bytes py_buffer
    cdef char *c_buffer
    if res < 0:
        py_buffer = b"\0" * C.AV_ERROR_MAX_STRING_SIZE
        c_buffer = py_buffer
        C.av_strerror(res, c_buffer, C.AV_ERROR_MAX_STRING_SIZE)
        raise LibError('%s (%d)' % (str(c_buffer), res))
    return res


def main(argv):
    
    print 'Starting.'
    
    cdef C.AVFormatContext *format_ctx = NULL
    cdef int video_stream_i = 0
    cdef int i = 0
    cdef C.AVCodecContext *codec_ctx = NULL
    cdef C.AVCodec *codec = NULL
    
    if len(argv) < 2:
        print 'usage: tutorial <movie>'
        exit(1)
    filename = os.path.abspath(argv[1])
    
    print 'Registering codecs.'
    C.av_register_all()
        
    print 'Opening', repr(filename)
    errcheck(C.avformat_open_input(&format_ctx, filename, NULL, NULL))
    
    print 'Getting stream info.'
    errcheck(C.avformat_find_stream_info(format_ctx, NULL))
    
    print 'Dumping to stderr.'
    C.av_dump_format(format_ctx, 0, filename, 0);
    
    print format_ctx.nb_streams, 'streams.'
    print 'Finding first video stream...'
    for i in range(format_ctx.nb_streams):
        if format_ctx.streams[i].codec.codec_type == C.AVMEDIA_TYPE_VIDEO:
            codec_ctx = format_ctx.streams[i].codec
            print '\tFound %r at %d.' % (codec_ctx.codec_name, i)
            break
    else:
        print 'Could not find video stream.'
        return
    
    # When I waited to fall out of the loop to extract the stream, I kept
    # segfaulting. Why was that?!
    
    # Find the decoder for the video stream.
    codec = C.avcodec_find_decoder(codec_ctx.codec_id)
    if codec == NULL:
        print 'Unsupported codec!'
        return
    
    print 'Done.'


