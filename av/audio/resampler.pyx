from libc.stdint cimport int64_t, uint8_t
cimport libav as lib

from av.audio.fifo cimport AudioFifo
from av.audio.format cimport get_audio_format
from av.audio.frame cimport alloc_audio_frame
from av.audio.layout cimport get_audio_layout
from av.error cimport err_check

from av.error import FFmpegError


cdef class AudioResampler(object):

    """AudioResampler(format=None, layout=None, rate=None)

    :param AudioFormat format: The target format, or string that parses to one
        (e.g. ``"s16"``).
    :param AudioLayout layout: The target layout, or an int/string that parses
        to one (e.g. ``"stereo"``).
    :param int rate: The target sample rate.


    """

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
        """resample(frame)

        Convert the ``sample_rate``, ``channel_layout`` and/or ``format`` of
        a :class:`~.AudioFrame`.

        :param AudioFrame frame: The frame to convert.
        :returns: A new :class:`AudioFrame` in new parameters, or the same frame
            if there is nothing to be done.
        :raises: ``ValueError`` if ``Frame.pts`` is set and non-simple.

        """

        if self.is_passthrough:
            return frame

        # Take source settings from the first frame.
        if not self.ptr:

            # We don't have any input, so don't bother even setting up.
            if not frame:
                return

            # Hold onto a copy of the attributes of the first frame to populate
            # output frames with.
            self.template = alloc_audio_frame()
            self.template._copy_internal_attributes(frame)
            self.template._init_user_attributes()

            # Set some default descriptors.
            self.format = self.format or self.template.format
            self.layout = self.layout or self.template.layout
            self.rate = self.rate or self.template.ptr.sample_rate

            # Check if there is actually work to do.
            if (
                self.template.format.sample_fmt == self.format.sample_fmt and
                self.template.layout.layout == self.layout.layout and
                self.template.ptr.sample_rate == self.rate
            ):
                self.is_passthrough = True
                return frame

            # Figure out our time bases.
            if frame._time_base.num and frame.ptr.sample_rate:
                self.pts_per_sample_in = frame._time_base.den / float(frame._time_base.num)
                self.pts_per_sample_in /= self.template.ptr.sample_rate

                # We will only provide outgoing PTS if the time_base is trivial.
                if frame._time_base.num == 1 and frame._time_base.den == frame.ptr.sample_rate:
                    self.simple_pts_out = True

            self.ptr = lib.swr_alloc()
            if not self.ptr:
                raise RuntimeError('Could not allocate SwrContext.')

            # Configure it!
            try:
                err_check(lib.av_opt_set_int(self.ptr, 'in_sample_fmt',      <int>self.template.format.sample_fmt, 0))
                err_check(lib.av_opt_set_int(self.ptr, 'out_sample_fmt',     <int>self.format.sample_fmt, 0))
                err_check(lib.av_opt_set_int(self.ptr, 'in_channel_layout',  self.template.layout.layout, 0))
                err_check(lib.av_opt_set_int(self.ptr, 'out_channel_layout', self.layout.layout, 0))
                err_check(lib.av_opt_set_int(self.ptr, 'in_sample_rate',     self.template.ptr.sample_rate, 0))
                err_check(lib.av_opt_set_int(self.ptr, 'out_sample_rate',    self.rate, 0))
                err_check(lib.swr_init(self.ptr))
            except FFmpegError:
                self.ptr = NULL
                raise

        elif frame:

            # Assert the settings are the same on consecutive frames.
            if (
                frame.ptr.format != self.template.format.sample_fmt or
                frame.ptr.channel_layout != self.template.layout.layout or
                frame.ptr.sample_rate != self.template.ptr.sample_rate
            ):
                raise ValueError('Frame does not match AudioResampler setup.')

        # Assert that the PTS are what we expect.
        cdef int64_t expected_pts
        if frame is not None and frame.ptr.pts != lib.AV_NOPTS_VALUE:
            expected_pts = <int64_t>(self.pts_per_sample_in * self.samples_in)
            if frame.ptr.pts != expected_pts:
                raise ValueError('Input frame pts %d != expected %d; fix or set to None.' % (frame.ptr.pts, expected_pts))
            self.samples_in += frame.ptr.nb_samples

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

        # Estimate out how many samples this will create; it will be high.
        # My investigations say that this swr_get_delay is not required, but
        # it is in the example loop, and avresample (as opposed to swresample)
        # may require it.
        cdef int output_nb_samples = lib.av_rescale_rnd(
            lib.swr_get_delay(self.ptr, self.rate) + frame.ptr.nb_samples,
            self.rate,
            self.template.ptr.sample_rate,
            lib.AV_ROUND_UP,
        ) if frame else lib.swr_get_delay(self.ptr, self.rate)

        # There aren't any frames coming, so no new frame pops out.
        if not output_nb_samples:
            return

        cdef AudioFrame output = alloc_audio_frame()
        output._copy_internal_attributes(self.template)
        output.ptr.sample_rate = self.rate
        output._init(
            self.format.sample_fmt,
            self.layout.layout,
            output_nb_samples,
            1,  # Align?
        )

        output.ptr.nb_samples = err_check(lib.swr_convert(
            self.ptr,
            output.ptr.extended_data,
            output_nb_samples,
            # Cast for const-ness, because Cython isn't expressive enough.
            <const uint8_t**>(frame.ptr.extended_data if frame else NULL),
            frame.ptr.nb_samples if frame else 0
        ))

        # Empty frame.
        if output.ptr.nb_samples <= 0:
            return

        # Create new PTSes in simple cases.
        if self.simple_pts_out:
            output._time_base.num = 1
            output._time_base.den = self.rate
            output.ptr.pts = self.samples_out
        else:
            output._time_base.num = 0
            output._time_base.den = 1
            output.ptr.pts = lib.AV_NOPTS_VALUE

        self.samples_out += output.ptr.nb_samples

        return output
