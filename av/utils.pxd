from libc.stdint cimport int64_t, uint8_t, uint64_t
from posix.types cimport suseconds_t, time_t
from posix.time cimport timeval

cimport libav as lib


cdef int stash_exception(exc_info=*)

cpdef int err_check(int res=*, filename=*) except -1



cdef dict avdict_to_dict(lib.AVDictionary *input, str encoding=*, str errors=*)
cdef dict_to_avdict(lib.AVDictionary **dst, dict src, bint clear=*, str encoding=*, str errors=*)


cdef object avrational_to_fraction(const lib.AVRational *input)
cdef object to_avrational(object value, lib.AVRational *input)


cdef flag_in_bitfield(uint64_t bitfield, uint64_t flag)


cdef extern from "time.h" nogil:
    cdef struct timezone:
        int tz_minuteswest
        int dsttime
    int gettimeofday(timeval *tp, timezone *tzp)
