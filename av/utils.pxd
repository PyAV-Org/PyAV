cimport libav as lib


cdef int err_check(int res) except -1

# Conversions.
cdef dict avdict_to_dict(lib.AVDictionary *input)
cdef object avrational_to_faction(lib.AVRational *input)
cdef object av_frac_to_fraction(lib.AVFrac *input)


