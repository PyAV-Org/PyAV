cimport libav as lib
from libc.errno cimport EAGAIN

from av.error cimport err_check
from av.packet cimport Packet
from av.stream cimport Stream


cdef class BitStreamFilterContext:
    """
    Initializes a bitstream filter: a way to directly modify packet data.

    Wraps :ffmpeg:`AVBSFContext`

    :param Stream in_stream: A stream that defines the input codec for the bitfilter.
    :param Stream out_stream: A stream whose codec is overwritten using the output parameters from the bitfilter.
    """
    def __cinit__(self, filter_description, Stream in_stream=None, Stream out_stream=None):
        cdef int res
        cdef char *filter_str = filter_description

        with nogil:
            res = lib.av_bsf_list_parse_str(filter_str, &self.ptr)
        err_check(res)

        if in_stream is not None:
            with nogil:
                res = lib.avcodec_parameters_copy(self.ptr.par_in, in_stream.ptr.codecpar)
            err_check(res)

        with nogil:
            res = lib.av_bsf_init(self.ptr)
        err_check(res)

        if out_stream is not None:
            with nogil:
                res = lib.avcodec_parameters_copy(out_stream.ptr.codecpar, self.ptr.par_out)
            err_check(res)
            lib.avcodec_parameters_to_context(out_stream.codec_context.ptr, out_stream.ptr.codecpar)

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

    cpdef flush(self):
        """
        Reset the internal state of the filter.
        Should be called e.g. when seeking.
        Can be used to make the filter usable again after draining it with EOF marker packet.
        """
        lib.av_bsf_flush(self.ptr)

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
