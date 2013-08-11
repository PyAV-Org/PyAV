from fractions import Fraction
from libc.stdint cimport int64_t, uint8_t, uint64_t
cimport libav as lib


class Error(ValueError):
    pass


# Would love to use the built-in constant, but it doesn't appear to
# exist on Travis, or my Linux workstation. Could this be because they
# are actually libav?
cdef int AV_ERROR_MAX_STRING_SIZE = 64


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
        py_buffer = b"\0" * AV_ERROR_MAX_STRING_SIZE
        c_buffer = py_buffer
        lib.av_strerror(res, c_buffer, AV_ERROR_MAX_STRING_SIZE)
        raise LibError(c_buffer, res)
    return res

cdef char* channel_layout_name(int nb_channels, uint64_t channel_layout):

    cdef char c_buffer[1024]    
    lib.av_get_channel_layout_string(c_buffer, 1024, nb_channels, channel_layout)

    return c_buffer

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

cdef object to_avrational(object value, lib.AVRational *input):

    if isinstance(value, Fraction):
        frac = value
    else:
        frac = Fraction(value)

    input.num = frac.numerator
    input.den = frac.denominator


cdef object av_frac_to_fraction(lib.AVFrac *input):
    return Fraction(input.val * input.num, input.den)

# this should behave the same as av_samples_alloc_array_and_samples
# older version of ffmpeg don't have that helper method

cdef int samples_alloc_array_and_samples(uint8_t ***audio_data, int *linesize, 
                                         int nb_channels, int nb_samples, 
                                            lib.AVSampleFormat sample_fmt, int align):
                                            
    cdef int ret = -1
    
    cdef int nb_planes
    
    if lib.av_sample_fmt_is_planar(sample_fmt):
        nb_planes = nb_channels
    else:
        nb_planes = 1
        
    audio_data[0] = <uint8_t **>lib.av_calloc(nb_planes, sizeof(audio_data[0][0]))
    
    if not audio_data[0]:
        return lib.AVERROR(lib.ENOMEM)
    
    ret = lib.av_samples_alloc(audio_data[0], linesize, nb_channels,
                           nb_samples, sample_fmt, align)
    
    if ret < 0:
        lib.av_freep(audio_data)
        
    
    
    return ret
