cdef class Frame(object):

    """Frame Base Class"""
        
    def __dealloc__(self):
        # These are all NULL safe.
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
