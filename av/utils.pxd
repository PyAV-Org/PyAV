cimport libav as lib


cdef dict avdict_to_dict(lib.AVDictionary *input, str encoding, str errors)
cdef void dict_to_avdict(lib.AVDictionary **dst, dict src, str encoding, str errors)

cdef void to_avrational(object frac, lib.AVRational *input)
cdef void check_ndarray(object array, object dtype, int ndim)
