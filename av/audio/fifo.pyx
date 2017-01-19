from av.audio.format cimport get_audio_format
from av.audio.frame cimport alloc_audio_frame
from av.audio.layout cimport get_audio_layout
from av.utils cimport err_check


cdef class AudioFifo:

    """A simple Audio FIFO (First In First Out) Buffer."""

    def __dealloc__(self):
        lib.av_audio_fifo_free(self.ptr)
        
    def __repr__(self):
        return '<av.%s nb_samples:%s %dhz %s %s at 0x%x>' % (
            self.__class__.__name__,
            self.samples,
            self.sample_rate,
            self.channel_layout,
            self.sample_fmt,
            id(self),
        )
     
    def __cinit__(self):
        self.last_pts = lib.AV_NOPTS_VALUE
        self.pts_offset = 0
        self.time_base.num = 1
        self.time_base.den = 1
        
    cpdef write(self, AudioFrame frame):
        """Push some samples into the queue."""

        # Take configuration from the first frame.
        if not self.ptr:

            self.format = get_audio_format(<lib.AVSampleFormat>frame.ptr.format)
            self.layout = get_audio_layout(0, frame.ptr.channel_layout)
            self.time_base.den = frame.ptr.sample_rate
            self.ptr = lib.av_audio_fifo_alloc(
                self.format.sample_fmt,
                len(self.layout.channels),
                frame.ptr.nb_samples * 2, # Just a default number of samples; it will adjust.
            )
            if not self.ptr:
                raise ValueError('could not create fifo')
        
        # Make sure nothing changed.
        else:
            if (
                frame.ptr.format != self.format.sample_fmt or
                frame.ptr.channel_layout != self.layout.layout or
                frame.ptr.sample_rate != self.time_base.den
            ):
                raise ValueError('frame does not match fifo parameters')

        if frame.ptr.pts != lib.AV_NOPTS_VALUE:
            self.last_pts = frame.ptr.pts
            self.pts_offset = self.samples
            
        err_check(lib.av_audio_fifo_write(
            self.ptr, 
            <void **>frame.ptr.extended_data,
            frame.ptr.nb_samples,
        ))


    cpdef read(self, unsigned int nb_samples=0, bint partial=False):
        """Read samples from the queue.

        :param int samples: The number of samples to pull; 0 gets all.
        :param bool partial: Allow returning less than requested.
        :returns: New :class:`AudioFrame` or ``None`` (if empty).

        If the incoming frames had valid timestamps, the returned frames
        will have accurate timestamps (assuming a time_base or 1/sample_rate).

        """

        if not self.samples:
            return

        nb_samples = nb_samples or self.samples
        if not nb_samples:
            return
        if not partial and self.samples < nb_samples:
            return

        if partial:
            nb_samples = min(self.samples, nb_samples)

        cdef int ret
        cdef int linesize
        cdef int sample_size

        cdef AudioFrame frame = alloc_audio_frame()
        frame._init(
            self.format.sample_fmt,
            self.layout.layout,
            nb_samples,
            1, # Align?
        )

        err_check(lib.av_audio_fifo_read(
            self.ptr,
            <void **>frame.ptr.extended_data,
            nb_samples,
        ))

        frame.ptr.sample_rate = self.time_base.den
        frame.ptr.channel_layout = self.layout.layout
        
        if self.last_pts != lib.AV_NOPTS_VALUE:
            frame.ptr.pts = self.last_pts - self.pts_offset
            self.pts_offset -= nb_samples
        
        return frame

    def iter(self, unsigned int nb_samples=0, bint partial=False):
        frame = self.read(nb_samples, partial)
        while frame:
            yield frame
            frame = self.read(nb_samples, partial)

    property samples:
        """Number of audio samples (per channel) """
        def __get__(self):
            return lib.av_audio_fifo_size(self.ptr)
    
    property rate:
        """Sample rate of the audio data. """
        def __get__(self):
            return self.time_base.den

