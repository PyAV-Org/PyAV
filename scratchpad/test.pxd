cdef extern from "libavutil/dict.h" nogil:

    #: Before AVStruct
    ctypedef struct AVStruct:
        #: Inside AVStruct
        pass
    #: After AVStruct

    #: Above av_function
    cdef void av_function(
        AVStruct **
    )
    #: Below av_function

    #: Above CONSTANT
    cdef int CONSTANT
    #: Below CONSTANT
