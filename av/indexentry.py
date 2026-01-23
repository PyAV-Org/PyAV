import cython
import cython.cimports.libav as lib


_cinit_bypass_sentinel = cython.declare(object, object())


@cython.cfunc
def wrap_index_entry(ptr: cython.pointer[lib.AVIndexEntry]) -> IndexEntry:
    obj: IndexEntry = IndexEntry(_cinit_bypass_sentinel)
    obj._init(ptr)
    return obj


@cython.cclass
class IndexEntry:
    def __cinit__(self, sentinel):
        if sentinel is not _cinit_bypass_sentinel:
            raise RuntimeError("cannot manually instantiate IndexEntry")

    @cython.cfunc
    def _init(self, ptr: cython.pointer[lib.AVIndexEntry]):
        self.ptr = ptr

    def __repr__(self):
        return (
            f"<av.IndexEntry pos={self.pos} timestamp={self.timestamp} flags={self.flags} "
            f"size={self.size} min_distance={self.min_distance}>"
        )

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
