
from cython.cimports import libav as lib

cdef object _cinit_bypass_sentinel = object()

cdef IndexEntry wrap_index_entry(lib.AVIndexEntry *ptr):
    cdef IndexEntry obj = IndexEntry(_cinit_bypass_sentinel)
    obj._init(ptr)
    return obj

cdef class IndexEntry:
    def __cinit__(self, sentinel):
        if sentinel is not _cinit_bypass_sentinel:
            raise RuntimeError("cannot manually instantiate IndexEntry")

    cdef _init(self, lib.AVIndexEntry *ptr):
        self.ptr = ptr

    def __repr__(self):
        return f"<av.IndexEntry pos={self.pos} timestamp={self.timestamp} flags={self.flags} size={self.size} min_distance={self.min_distance}>"

    @property
    def pos(self):
        return self.ptr.pos

    @property
    def timestamp(self):
        return self.ptr.timestamp   
    
    @property
    def flags(self):
        return self.ptr.flags

    @property
    def is_keyframe(self):
        return bool(self.ptr.flags & lib.AVINDEX_KEYFRAME)

    @property
    def is_discard(self):
        return bool(self.ptr.flags & lib.AVINDEX_DISCARD_FRAME)
    
    @property
    def size(self):
        return self.ptr.size
    
    @property
    def min_distance(self): 
        return self.ptr.min_distance
