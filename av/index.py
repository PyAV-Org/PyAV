import cython
import cython.cimports.libav as lib
from cython.cimports.libc.stdint import int64_t

_cinit_bypass_sentinel = cython.declare(object, object())


@cython.cfunc
def wrap_index_entry(ptr: cython.pointer[lib.AVIndexEntry]) -> IndexEntry:
    obj: IndexEntry = IndexEntry(_cinit_bypass_sentinel)
    obj._init(ptr)
    return obj


@cython.cclass
class IndexEntry:
    """A single entry from a stream's index.

    This is a thin wrapper around FFmpeg's ``AVIndexEntry``.

    The exact meaning of the fields depends on the container/demuxer.
    """

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


@cython.cfunc
def wrap_index_entries(ptr: cython.pointer[lib.AVStream]) -> IndexEntries:
    obj: IndexEntries = IndexEntries(_cinit_bypass_sentinel)
    obj._init(ptr)
    return obj


@cython.cclass
class IndexEntries:
    """A sequence-like view of FFmpeg's per-stream index entries.

    Exposed as :attr:`~av.stream.Stream.index_entries`.

    The index is provided by the demuxer and may be empty or incomplete depending
    on the container format. This is useful for fast multi-seek loops (e.g., decoding
    at a lower-than-native framerate).
    """

    def __cinit__(self, sentinel):
        if sentinel is _cinit_bypass_sentinel:
            return
        raise RuntimeError("cannot manually instantiate IndexEntries")

    @cython.cfunc
    def _init(self, ptr: cython.pointer[lib.AVStream]):
        self.stream_ptr = ptr

    def __repr__(self):
        return f"<av.IndexEntries[{len(self)}]>"

    def __len__(self) -> int:
        with cython.nogil:
            return lib.avformat_index_get_entries_count(self.stream_ptr)

    def __iter__(self):
        for i in range(len(self)):
            yield self[i]

    def __getitem__(self, index):
        if isinstance(index, int):
            n = len(self)
            if index < 0:
                index += n
            if index < 0 or index >= n:
                raise IndexError(f"Index entries {index} out of bounds for size {n}")

            c_idx = cython.declare(cython.int, index)
            with cython.nogil:
                entry = lib.avformat_index_get_entry(self.stream_ptr, c_idx)

            if entry == cython.NULL:
                raise IndexError("index entry not found")

            return wrap_index_entry(entry)

        elif isinstance(index, slice):
            start, stop, step = index.indices(len(self))
            return [self[i] for i in range(start, stop, step)]

        else:
            raise TypeError("Index must be an integer or a slice")

    def search_timestamp(
        self, timestamp, *, backward: bool = True, any_frame: bool = False
    ):
        """Search the underlying index for ``timestamp``.

        This wraps FFmpeg's ``av_index_search_timestamp``.

        Returns an index into this object, or ``-1`` if no match is found.
        """
        c_timestamp = cython.declare(int64_t, timestamp)
        flags = cython.declare(cython.int, 0)

        if backward:
            flags |= lib.AVSEEK_FLAG_BACKWARD
        if any_frame:
            flags |= lib.AVSEEK_FLAG_ANY

        with cython.nogil:
            idx = lib.av_index_search_timestamp(self.stream_ptr, c_timestamp, flags)

        return idx
