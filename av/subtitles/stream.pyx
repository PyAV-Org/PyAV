cdef class SubtitleStream(Stream):
    """
    A :class:`SubtitleStream` can contain many :class:`SubtitleSet` objects accessible via decoding.
    """
    def __getattr__(self, name):
        return getattr(self.codec_context, name)
