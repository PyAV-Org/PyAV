cdef extern from "Python.h":
    
    cdef object PyBuffer_FromMemory(void *ptr, size_t size)


include "libavutil.pxd"
include "libavcodec.pxd"
include "libavformat.pxd"
include "libswscale.pxd"

