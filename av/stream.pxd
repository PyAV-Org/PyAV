cimport libav as lib

from av.codec.context cimport CodecContext
from av.container.core cimport Container
from av.frame cimport Frame
from av.packet cimport Packet


cdef class Stream:
    cdef lib.AVStream *ptr

    # Stream attributes.
    cdef readonly Container container
    cdef readonly dict metadata

    # CodecContext attributes.
    cdef readonly CodecContext codec_context

    # Private API.
    cdef _init(self, Container, lib.AVStream*, CodecContext)
    cdef _finalize_for_output(self)
    cdef _set_id(self, value)


cdef Stream wrap_stream(Container, lib.AVStream*, CodecContext)


cdef class DataStream(Stream):
    pass

cdef class AttachmentStream(Stream):
    pass
