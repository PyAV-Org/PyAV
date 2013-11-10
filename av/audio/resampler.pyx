from libc.stdint cimport uint64_t

cimport libav as lib

from av.audio.fifo cimport AudioFifo
from av.audio.format cimport get_audio_format
from av.audio.frame cimport alloc_audio_frame
from av.audio.layout cimport get_audio_layout
from av.utils cimport err_check


cdef class AudioResampler(object):

    def __cinit__(self, format=None, layout=None, rate=None):
        if format is not None:
            self.format = format if isinstance(format, AudioFormat) else AudioFormat(format)
        if layout is not None:
            self.layout = layout if isinstance(layout, AudioLayout) else AudioLayout(layout)
        self.rate = int(rate) if rate else 0

    def __dealloc__(self):
        if self.ptr:
            lib.swr_close(self.ptr)
        lib.swr_free(&self.ptr)

    cpdef resample(self, AudioFrame frame):
        
        # Take source settings from the first frame.
        if not self.ptr:

            # Grab the source descriptors.
            self.src_format = get_audio_format(<lib.AVSampleFormat>frame.ptr.format)
            self.src_layout = get_audio_layout(0, frame.ptr.channel_layout)
            self.src_rate = frame.ptr.sample_rate

            # Set some default descriptors.
            self.format = self.format or self.src_format
            self.layout = self.layout or self.src_layout
            self.rate = self.rate or self.src_rate

            self.ptr = lib.swr_alloc()
            if not self.ptr:
                raise ValueError('could not create SwrContext')

            # Configure it!
            try:
                err_check(lib.av_opt_set_int(self.ptr, 'in_sample_fmt',      <int>self.src_format.sample_fmt, 0))
                err_check(lib.av_opt_set_int(self.ptr, 'out_sample_fmt',     <int>self.format.sample_fmt, 0))
                err_check(lib.av_opt_set_int(self.ptr, 'in_channel_layout',  self.src_layout.layout, 0))
                err_check(lib.av_opt_set_int(self.ptr, 'out_channel_layout', self.layout.layout, 0))
                err_check(lib.av_opt_set_int(self.ptr, 'in_sample_rate',     self.src_rate, 0))
                err_check(lib.av_opt_set_int(self.ptr, 'out_sample_rate',    self.rate, 0))
                err_check(lib.swr_init(self.ptr))
            except:
                self.ptr = NULL
                raise

        # Make sure the settings are the same on consecutive frames.
        else:
            if (
                frame.ptr.format != self.src_format.sample_fmt or
                frame.ptr.channel_layout != self.src_layout.layout or
                frame.ptr.sample_rate != self.src_rate
            ):
                raise ValueError('frame does not match resampler parameters')


        # The example "loop" as given in the FFmpeg documentation looks like:
        # uint8_t **input;
        # int in_samples;
        # while (get_input(&input, &in_samples)) {
        #     uint8_t *output;
        #     int out_samples = av_rescale_rnd(swr_get_delay(swr, 48000) +
        #                                      in_samples, 44100, 48000, AV_ROUND_UP);
        #     av_samples_alloc(&output, NULL, 2, out_samples,
        #                      AV_SAMPLE_FMT_S16, 0);
        #     out_samples = swr_convert(swr, &output, out_samples,
        #                                      input, in_samples);
        #     handle_output(output, out_samples);
        #     av_freep(&output);
        # }
        
        # Figure out how many frames this will create.
        cdef int output_nb_samples = lib.av_rescale_rnd(
            lib.swr_get_delay(self.ptr, self.rate) + frame.ptr.nb_samples,
            self.rate,
            self.src_rate,
            lib.AV_ROUND_UP,
        )
        print frame.ptr.nb_samples, 'converts to', output_nb_samples
        
        cdef AudioFrame output = alloc_audio_frame()
        output.ptr.sample_rate = self.rate
        output._init(
            self.format.sample_fmt,
            self.layout.layout,
            output_nb_samples,
            1, # Align?
        )

        # HACK: This used to be nessesary for unknown reasons.
        # if lib.USING_AVRESAMPLE:
        #    src_nb_samples += 1000

        output.ptr.nb_samples = err_check(lib.swr_convert(
            self.ptr,
            output.ptr.extended_data,
            output_nb_samples,
            frame.ptr.extended_data,
            frame.ptr.nb_samples
        ))

        # Recalculate linesizes and various properties.
        output._fill()

        print 'expected', output_nb_samples, 'got', output.ptr.nb_samples

        # Flush
        # ret = err_check(lib.swr_convert(self.ptr,
        #                       frame.ptr.extended_data,dst_nb_samples,
        #                       NULL, 0))
        
        return output
        

