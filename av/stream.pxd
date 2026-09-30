cimport libav as lib

from av.codec.context cimport CodecContext
from av.container.core cimport Container
from av.frame cimport Frame
from av.packet cimport Packet


cdef class Stream:
    cdef lib.AVStream *ptr
    cdef readonly Container container
    cdef readonly dict metadata
    cdef readonly CodecContext codec_context
    cdef _init(self, Container, lib.AVStream*, CodecContext)
    cdef bint _is_open(self)
    cdef void _assert_open(self)
    cdef _assert_has_codec_context(self, int err=*)
    cdef _finalize_for_output(self)
    cdef _set_id(self, value)


cdef Stream wrap_stream(Container, lib.AVStream*, CodecContext)


cdef class DataStream(Stream):
    pass

cdef class AttachmentStream(Stream):
    pass
