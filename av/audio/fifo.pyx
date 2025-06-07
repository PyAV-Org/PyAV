from av.audio.frame cimport alloc_audio_frame
from av.error cimport err_check


cdef class AudioFifo:
    """A simple audio sample FIFO (First In First Out) buffer."""

    def __repr__(self):
        try:
            result = (
                f"<av.{self.__class__.__name__} {self.samples} samples of "
                f"{self.sample_rate}hz {self.layout} {self.format} at 0x{id(self):x}>"
            )
        except AttributeError:
            result = (
                f"<av.{self.__class__.__name__} uninitialized, use fifo.write(frame),"
                f" at 0x{id(self):x}>"
            )
        return result

    def __dealloc__(self):
        if self.ptr:
            lib.av_audio_fifo_free(self.ptr)

    cpdef write(self, AudioFrame frame):
        """write(frame)

        Push a frame of samples into the queue.

        :param AudioFrame frame: The frame of samples to push.

        The FIFO will remember the attributes from the first frame, and use those
        to populate all output frames.

        If there is a :attr:`~.Frame.pts` and :attr:`~.Frame.time_base` and
        :attr:`~.AudioFrame.sample_rate`, then the FIFO will assert that the incoming
        timestamps are continuous.

        """

        if frame is None:
            raise TypeError("AudioFifo must be given an AudioFrame.")

        if not frame.ptr.nb_samples:
            return

        if not self.ptr:

            # Hold onto a copy of the attributes of the first frame to populate
            # output frames with.
            self.template = alloc_audio_frame()
            self.template._copy_internal_attributes(frame)
            self.template._init_user_attributes()

            # Figure out our "time_base".
            if frame._time_base.num and frame.ptr.sample_rate:
                self.pts_per_sample = frame._time_base.den / float(frame._time_base.num)
                self.pts_per_sample /= frame.ptr.sample_rate
            else:
                self.pts_per_sample = 0

            self.ptr = lib.av_audio_fifo_alloc(
                <lib.AVSampleFormat>frame.ptr.format,
                frame.layout.nb_channels,
                frame.ptr.nb_samples * 2,  # Just a default number of samples; it will adjust.
            )

            if not self.ptr:
                raise RuntimeError("Could not allocate AVAudioFifo.")

        # Make sure nothing changed.
        elif (
            frame.ptr.format != self.template.ptr.format or
            # TODO: frame.ptr.ch_layout != self.template.ptr.ch_layout or
            frame.ptr.sample_rate != self.template.ptr.sample_rate or
            (frame._time_base.num and self.template._time_base.num and (
                frame._time_base.num != self.template._time_base.num or
                frame._time_base.den != self.template._time_base.den
            ))
        ):
            raise ValueError("Frame does not match AudioFifo parameters.")

        # Assert that the PTS are what we expect.
        cdef int64_t expected_pts
        if self.pts_per_sample and frame.ptr.pts != lib.AV_NOPTS_VALUE:
            expected_pts = <int64_t>(self.pts_per_sample * self.samples_written)
            if frame.ptr.pts != expected_pts:
                raise ValueError(
                    "Frame.pts (%d) != expected (%d); fix or set to None." % (frame.ptr.pts, expected_pts)
                )

        err_check(lib.av_audio_fifo_write(
            self.ptr,
            <void **>frame.ptr.extended_data,
            frame.ptr.nb_samples,
        ))

        self.samples_written += frame.ptr.nb_samples

    cpdef read(self, int samples=0, bint partial=False):
        """read(samples=0, partial=False)

        Read samples from the queue.

        :param int samples: The number of samples to pull; 0 gets all.
        :param bool partial: Allow returning less than requested.
        :returns: New :class:`AudioFrame` or ``None`` (if empty).

        If the incoming frames had valid a :attr:`~.Frame.time_base`,
        :attr:`~.AudioFrame.sample_rate` and :attr:`~.Frame.pts`, the returned frames
        will have accurate timing.

        """

        if not self.ptr:
            return

        cdef int buffered_samples = lib.av_audio_fifo_size(self.ptr)
        if buffered_samples < 1:
            return

        samples = samples or buffered_samples

        if buffered_samples < samples:
            if partial:
                samples = buffered_samples
            else:
                return

        cdef AudioFrame frame = alloc_audio_frame()
        frame._copy_internal_attributes(self.template)
        frame._init(
            <lib.AVSampleFormat>self.template.ptr.format,
            <lib.AVChannelLayout>self.template.ptr.ch_layout,
            samples,
            1,  # Align?
        )

        err_check(lib.av_audio_fifo_read(
            self.ptr,
            <void **>frame.ptr.extended_data,
            samples,
        ))

        if self.pts_per_sample:
            frame.ptr.pts = <uint64_t>(self.pts_per_sample * self.samples_read)
        else:
            frame.ptr.pts = lib.AV_NOPTS_VALUE

        self.samples_read += samples

        return frame

    cpdef read_many(self, int samples, bint partial=False):
        """read_many(samples, partial=False)

        Read as many frames as we can.

        :param int samples: How large for the frames to be.
        :param bool partial: If we should return a partial frame.
        :returns: A ``list`` of :class:`AudioFrame`.

        """

        cdef AudioFrame frame
        frames = []
        while True:
            frame = self.read(samples, partial=partial)
            if frame is not None:
                frames.append(frame)
            else:
                break

        return frames

    @property
    def format(self):
        """The :class:`.AudioFormat` of this FIFO."""
        if not self.ptr:
            raise AttributeError(f"'{__name__}.AudioFifo' object has no attribute 'format'")
        return self.template.format
    @property
    def layout(self):
        """The :class:`.AudioLayout` of this FIFO."""
        if not self.ptr:
            raise AttributeError(f"'{__name__}.AudioFifo' object has no attribute 'layout'")
        return self.template.layout
    @property
    def sample_rate(self):
        if not self.ptr:
            raise AttributeError(f"'{__name__}.AudioFifo' object has no attribute 'sample_rate'")
        return self.template.sample_rate

    @property
    def samples(self):
        """Number of audio samples (per channel) in the buffer."""
        return lib.av_audio_fifo_size(self.ptr) if self.ptr else 0
