cimport libav as lib

from av.codec.context cimport CodecContext
from av.container.core cimport Container
from av.frame cimport Frame
from av.index cimport IndexEntries
from av.packet cimport Packet


cdef class Stream:
    cdef lib.AVStream *ptr

    # Stream attributes.
    cdef readonly Container container
    cdef readonly dict metadata

    # CodecContext attributes.
    cdef readonly CodecContext codec_context

    cdef readonly IndexEntries index_entries

    # Display (rotation) matrix to write as AV_PKT_DATA_DISPLAYMATRIX coded
    # side data at mux time. Exactly one of these is set at a time (or neither):
    #   _display_matrix:   native-endian packed bytes (9 int32), raw form.
    #   _display_rotation: (degrees, hflip, vflip), built via FFmpeg helpers.
    cdef bytes _display_matrix
    cdef object _display_rotation

    # Private API.
    cdef _init(self, Container, lib.AVStream*, CodecContext)
    cdef _finalize_for_output(self)
    cdef _apply_display_matrix(self)
    cdef _set_id(self, value)


cdef Stream wrap_stream(Container, lib.AVStream*, CodecContext)


cdef class DataStream(Stream):
    pass

cdef class AttachmentStream(Stream):
    pass
