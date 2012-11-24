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
    
    if len(argv) < 2:
        print 'usage: tutorial <movie>'
        exit(1)
    filename = os.path.abspath(argv[1])
    
    print 'Registering codecs.'
    C.av_register_all()
    
    # NULL implies that opening a file will allocate this object.
    cdef C.AVFormatContext *ctx = NULL
    
    print 'Opening', repr(filename)
    errcheck(C.avformat_open_input(&ctx, filename, NULL, NULL))
    
    print 'Getting stream info.'
    errcheck(C.avformat_find_stream_info(ctx, NULL))
    
    print 'Dumping to stderr.'
    C.av_dump_format(ctx, 0, filename, 0);
    
    print 'Done.'


