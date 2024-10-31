cimport libav as lib
from libc.stdint cimport uint64_t


cdef dict avdict_to_dict(lib.AVDictionary *input, str encoding, str errors)
cdef dict_to_avdict(lib.AVDictionary **dst, dict src, str encoding, str errors)

cdef object avrational_to_fraction(const lib.AVRational *input)
cdef void to_avrational(object frac, lib.AVRational *input)

cdef check_ndarray(object array, object dtype, int ndim)
cdef flag_in_bitfield(uint64_t bitfield, uint64_t flag)
