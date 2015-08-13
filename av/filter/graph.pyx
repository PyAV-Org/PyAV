from libc.string cimport memcpy

from av.utils cimport err_check
from av.video.frame cimport VideoFrame, alloc_video_frame


cdef class Graph(object):

    def __cinit__(self):

        filter_str = "mandelbrot"

        self.ptr = lib.avfilter_graph_alloc()

        err_check(lib.avfilter_graph_parse2(self.ptr, filter_str, &self.inputs, &self.outputs))

        cdef lib.AVFilterInOut *input_ = self.inputs
        while input_ != NULL:
            print 'in ', input_.pad_idx, (input_.name if input_.name != NULL else ''), input_.filter_ctx.name, input_.filter_ctx.filter.name
            input_ = input_.next

        cdef lib.AVFilterInOut *output = self.outputs
        while output != NULL:
            print 'out', output.pad_idx, (output.name if output.name != NULL else ''), output.filter_ctx.name, output.filter_ctx.filter.name
            output = output.next

        cdef lib.AVFilter *sink = lib.avfilter_get_by_name("buffersink")

        err_check(lib.avfilter_graph_create_filter(
            &self.sink_ctx,
            sink,
            "out",
            "",
            NULL,
            self.ptr
        ))

        lib.avfilter_link(self.outputs[0].filter_ctx, self.outputs[0].pad_idx, self.sink_ctx, 0)

        err_check(lib.avfilter_graph_config(self.ptr, NULL))

    def __dealloc__(self):
        if self.inputs:
            lib.avfilter_inout_free(&self.inputs)
        if self.outputs:
            lib.avfilter_inout_free(&self.outputs)
        lib.avfilter_graph_free(&self.ptr)

    def dump(self):
        cdef char *buf = lib.avfilter_graph_dump(self.ptr, "")
        cdef str ret = buf
        lib.av_free(buf)
        return ret

    def pull(self):

        cdef lib.AVFilterBufferRef *bufref
        err_check(lib.av_buffersink_get_buffer_ref(self.sink_ctx, &bufref, 0))

        cdef VideoFrame frame = alloc_video_frame()

        memcpy(frame.ptr.data, bufref.data, sizeof(frame.ptr.data))
        memcpy(frame.ptr.linesize, bufref.linesize, sizeof(frame.ptr.linesize))
        memcpy(frame.ptr.extended_data, bufref.extended_data, sizeof(frame.ptr.extended_data))
        frame.ptr.width = bufref.buf.w
        frame.ptr.height = bufref.buf.h
        frame.ptr.format = <lib.AVPixelFormat>bufref.format
        frame.ptr.pts = bufref.pts
        frame._init_properties()

        lib.avfilter_unref_bufferp(&bufref)

        return frame


