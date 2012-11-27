from fractions import Fraction

cimport libav as lib


class Error(ValueError):
    pass


class LibError(Error):
    
    def __init__(self, msg, code=0):
        super(LibError, self).__init__(msg, code)
    
    @property
    def code(self):
        return self.args[1]
            
    def __str__(self):
        if self.args[1]:
            return '[Errno %d] %s' % (self.args[1], self.args[0])
        else:
            return '%s' % (self.args[0])


cdef int err_check(int res) except -1:
    cdef bytes py_buffer
    cdef char *c_buffer
    if res < 0:
        py_buffer = b"\0" * lib.AV_ERROR_MAX_STRING_SIZE
        c_buffer = py_buffer
        lib.av_strerror(res, c_buffer, lib.AV_ERROR_MAX_STRING_SIZE)
        raise LibError(c_buffer, res)
    return res


cdef dict avdict_to_dict(lib.AVDictionary *input):
    
    cdef lib.AVDictionaryEntry *element = NULL
    cdef dict output = {}
    while True:
        element = lib.av_dict_get(input, "", element, lib.AV_DICT_IGNORE_SUFFIX)
        if element == NULL:
            break
        output[element.key] = element.value
    return output


cdef object avrational_to_faction(lib.AVRational *input):
    return Fraction(input.num, input.den) if input.den else Fraction(0, 1)


cdef object av_frac_to_fraction(lib.AVFrac *input):
    return Fraction(input.val * input.num, input.den)
