from libc.limits cimport INT_MAX

from cpython cimport Py_INCREF, PyTuple_New, PyTuple_SET_ITEM

from av.plane cimport Plane
from av.utils cimport avrational_to_faction


cdef class Frame(object):

    """Frame Base Class"""

    def __cinit__(self, *args, **kwargs):
        with nogil:
            self.ptr = lib.av_frame_alloc()

    def __dealloc__(self):
        with nogil:
            lib.av_frame_free(&self.ptr)

    def __repr__(self):
        return 'av.%s #%d at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            id(self),
        )

    property dts:

        def __get__(self):
            if self.ptr.pkt_dts == lib.AV_NOPTS_VALUE:
                return None
            return self.ptr.pkt_dts

    property pts:

        def __get__(self):
            if self.ptr.pts == lib.AV_NOPTS_VALUE:
                return None
            return self.ptr.pts

        def __set__(self, value):
            if value is None:
                self.ptr.pts = lib.AV_NOPTS_VALUE
            else:
                self.ptr.pts = value

    property time:

        def __get__(self):
            if self.ptr.pts == lib.AV_NOPTS_VALUE:
                return None
            else:
                return float(self.ptr.pts) * self._time_base.num / self._time_base.den

    property time_base:

        def __get__(self):
            return avrational_to_faction(&self._time_base)

        def __set__(self, value):
            self._time_base.num = value.numerator
            self._time_base.den = value.denominator

    cdef _init_planes(self, cls=Plane):

        # We need to detect which planes actually exist, but also contrain
        # ourselves to the maximum plane count (as determined only by VideoFrames
        # so far), in case the library implementation does not set the last
        # plane to NULL.
        cdef int max_plane_count = self._max_plane_count()
        cdef int plane_count = 0
        while plane_count < max_plane_count and self.ptr.extended_data[plane_count]:
            plane_count += 1

        self.planes = PyTuple_New(plane_count)
        for i in range(plane_count):
            # We are constructing this tuple manually, but since Cython does
            # not understand reference stealing we must manually Py_INCREF
            # so that when Cython Py_DECREFs it doesn't release our object.
            plane = cls(self, i)
            Py_INCREF(plane)
            PyTuple_SET_ITEM(self.planes, i, plane)

    cdef int _max_plane_count(self):
        return INT_MAX

    cdef _copy_attributes_from(self, Frame other):
        self.index = other.index
        self._time_base = other._time_base
        if self.ptr and other.ptr:
            self.ptr.pkt_pts = other.ptr.pkt_pts
            self.ptr.pkt_dts = other.ptr.pkt_dts
            self.ptr.pts = other.ptr.pts
    
    cdef _init_properties(self):
        pass # Dummy to match the API of the others.

