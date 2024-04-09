cimport libav as lib
from libc.errno cimport EAGAIN

from av.error cimport err_check
from av.packet cimport Packet
from av.stream cimport Stream


cdef class BitStreamFilterContext:
    """
    Initializes a bitstream filter: a way to directly modify packet data.

    Wraps :ffmpeg:`AVBSFContext`
    """
    def __cinit__(self, filter_description, Stream stream=None):
        cdef int res
        cdef char *filter_str = filter_description

        with nogil:
            res = lib.av_bsf_list_parse_str(filter_str, &self.ptr)
        err_check(res)

        if stream is not None:
            with nogil:
                res = lib.avcodec_parameters_copy(self.ptr.par_in, stream.ptr.codecpar)
            err_check(res)
            with nogil:
                res = lib.avcodec_parameters_copy(self.ptr.par_out, stream.ptr.codecpar)
            err_check(res)

        with nogil:
            res = lib.av_bsf_init(self.ptr)
        err_check(res)

    def __dealloc__(self):
        if self.ptr:
            lib.av_bsf_free(&self.ptr)

    cpdef filter(self, Packet packet=None):
        """
        Processes a packet based on the filter_description set during initialization.
        Multiple packets may be created.

        :type: list[Packet]
        """
        cdef int res
        cdef Packet new_packet

        with nogil:
            res = lib.av_bsf_send_packet(self.ptr, packet.ptr if packet is not None else NULL)
        err_check(res)

        output = []
        while True:
            new_packet = Packet()
            with nogil:
                res = lib.av_bsf_receive_packet(self.ptr, new_packet.ptr)

            if res == -EAGAIN or res == lib.AVERROR_EOF:
                return output

            err_check(res)
            if res:
                return output

            output.append(new_packet)


cdef get_filter_names():
    names = set()
    cdef const lib.AVBitStreamFilter *ptr
    cdef void *opaque = NULL
    while True:
        ptr = lib.av_bsf_iterate(&opaque)
        if ptr:
            names.add(ptr.name)
        else:
            break

    return names

bitstream_filters_available = get_filter_names()
