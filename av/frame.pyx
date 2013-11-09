from cpython cimport Py_INCREF, PyTuple_New, PyTuple_SET_ITEM

from av.plane cimport Plane


cdef class Frame(object):

    """Frame Base Class"""
    
    def __cinit__(self, *args, **kwargs):
        self.ptr = lib.avcodec_alloc_frame()
        lib.avcodec_get_frame_defaults(self.ptr)

    def __dealloc__(self):
        lib.avcodec_free_frame(&self.ptr)
        
    property pts:
        """Presentation time stamp of this frame."""
        def __get__(self):
            if self.ptr.pts == lib.AV_NOPTS_VALUE:
                return None
            return self.ptr.pts
        def __set__(self, value):
            if value is None:
                self.ptr.pts = lib.AV_NOPTS_VALUE
            else:
                self.ptr.pts = value

    cdef _init_planes(self, cls=Plane):

        # Construct the planes.
        cdef int plane_count = 0
        for i in range(lib.AV_NUM_DATA_POINTERS):
            if self.ptr.data[i]:
                plane_count = i + 1
            else:
                break
        self.planes = PyTuple_New(plane_count)
        for i in range(plane_count):
            # We are constructing this tuple manually, but since Cython does
            # not understand reference stealing we must manually Py_INCREF
            # so that when Cython Py_DECREFs it doesn't release our object.
            plane = cls(self, i)
            Py_INCREF(plane)
            PyTuple_SET_ITEM(self.planes, i, plane)

