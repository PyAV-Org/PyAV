cimport libav as lib


cdef object _cinit_sentinel = object()

cdef Option wrap_option(lib.AVOption *ptr):
    if ptr == NULL:
        return None
    cdef Option obj = Option(_cinit_sentinel)
    obj.ptr = ptr
    return obj


cdef dict _TYPE_NAMES = {
    lib.AV_OPT_TYPE_FLAGS: 'FLAGS',   
    lib.AV_OPT_TYPE_INT: 'INT',     
    lib.AV_OPT_TYPE_INT64: 'INT64',   
    lib.AV_OPT_TYPE_DOUBLE: 'DOUBLE',  
    lib.AV_OPT_TYPE_FLOAT: 'FLOAT',   
    lib.AV_OPT_TYPE_STRING: 'STRING',  
    lib.AV_OPT_TYPE_RATIONAL: 'RATIONAL',    
    lib.AV_OPT_TYPE_BINARY: 'BINARY',  
    #lib.AV_OPT_TYPE_DICT: 'DICT', # Recent addition; does not always exist.
    lib.AV_OPT_TYPE_CONST: 'CONST',   
    #lib.AV_OPT_TYPE_IMAGE_SIZE: 'IMAGE_SIZE',  
    #lib.AV_OPT_TYPE_PIXEL_FMT: 'PIXEL_FMT',   
    #lib.AV_OPT_TYPE_SAMPLE_FMT: 'SAMPLE_FMT',  
    #lib.AV_OPT_TYPE_VIDEO_RATE: 'VIDEO_RATE',  
    #lib.AV_OPT_TYPE_DURATION: 'DURATION',    
    #lib.AV_OPT_TYPE_COLOR: 'COLOR',   
    #lib.AV_OPT_TYPE_CHANNEL_LAYOUT: 'CHANNEL_LAYOUT',  
}


cdef class Option(object):

    def __cinit__(self, sentinel):
        if sentinel != _cinit_sentinel:
            raise RuntimeError('Cannot construct av.Option')

    property name:
        def __get__(self):
            return self.ptr.name

    property type:
        def __get__(self):
            return _TYPE_NAMES[self.ptr.type]

    property help:
        def __get__(self):
            return self.ptr.help if self.ptr.help != NULL else ''

    def __repr__(self):
        return '<av.%s %s at 0x%x>' % (self.__class__.__name__, self.name, id(self))

