from libc.stdint cimport int64_t, uint8_t, uint64_t

cimport libav as lib


cdef int stash_exception(exc_info=*)

cdef int err_check(int res=*, str filename=*) except -1



cdef dict avdict_to_dict(lib.AVDictionary *input)
cdef dict_to_avdict(lib.AVDictionary **dst, dict src, bint clear=*)



cdef object avrational_to_faction(lib.AVRational *input)
cdef object to_avrational(object value, lib.AVRational *input)
cdef object av_frac_to_fraction(lib.AVFrac *input)


cdef str media_type_to_string(lib.AVMediaType)
