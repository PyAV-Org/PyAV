import cython
import cython.cimports.libav as lib
from cython.cimports.av.container.core import Container
from cython.cimports.av.utils import avdict_to_dict

from av.stream import Discard

_cinit_bypass_sentinel = cython.declare(object, object())


@cython.cfunc
def wrap_program(container: Container, index: cython.int) -> Program:
    obj: Program = Program(_cinit_bypass_sentinel)
    obj.container = container
    obj.index = index
    return obj


@cython.final
@cython.cclass
class Program:
    """A program in a container: a group of streams that play together.

    MPEG-TS carries several programs (TV channels, in broadcast) in one stream.
    Other formats, such as HLS, use programs for their variants.

    Wraps :ffmpeg:`AVProgram`. Get one from :attr:`.InputContainer.programs`.
    """

    def __cinit__(self, sentinel):
        if sentinel is not _cinit_bypass_sentinel:
            raise RuntimeError("cannot manually instantiate Program")

    @cython.cfunc
    def _ptr(self) -> cython.pointer[lib.AVProgram]:
        self.container._assert_open()
        return self.container.ptr.programs[self.index]

    def __repr__(self):
        if self.container.ptr == cython.NULL:
            return f"<av.Program #{self.index} (container closed) at 0x{id(self):x}>"
        return (
            f"<av.Program #{self.index} id={self.id}, "
            f"{len(self.streams)} streams at 0x{id(self):x}>"
        )

    @property
    def id(self):
        """The format-specific ID of this program. In MPEG-TS, this is the
        program number (service ID).

        :type: int
        """
        return self._ptr().id

    @property
    def program_num(self):
        """The MPEG-TS program number, or 0 for other formats.

        :type: int
        """
        return self._ptr().program_num

    @property
    def pmt_pid(self):
        """The PID of this program's Program Map Table in MPEG-TS.

        :type: int
        """
        return self._ptr().pmt_pid

    @property
    def pcr_pid(self):
        """The PID carrying this program's clock reference in MPEG-TS.

        :type: int
        """
        return self._ptr().pcr_pid

    @property
    def metadata(self):
        """Metadata for this program, such as ``service_name`` and
        ``service_provider`` in MPEG-TS.

        :type: dict[str, str]
        """
        return avdict_to_dict(self._ptr().metadata)

    @property
    def streams(self):
        """The streams that belong to this program.

        A stream can belong to more than one program.

        :type: tuple[Stream, ...]
        """
        ptr: cython.pointer[lib.AVProgram] = self._ptr()
        by_index = {stream.index: stream for stream in self.container.streams}
        result = []
        i: cython.uint
        for i in range(ptr.nb_stream_indexes):
            stream = by_index.get(ptr.stream_index[i])
            if stream is not None:
                result.append(stream)
        return tuple(result)

    @property
    def discard(self):
        """Controls whether the demuxer reads this program's packets.

        Set to :attr:`.Discard.all` to skip a program entirely. In MPEG-TS, a
        stream's packets are only dropped once every program it belongs to is
        discarded.

        :type: Discard
        """
        return Discard(self._ptr().discard)

    @discard.setter
    def discard(self, value):
        self._ptr().discard = Discard(value).value
