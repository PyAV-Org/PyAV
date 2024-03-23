cdef class SubtitleStream(Stream):
    def __getattr__(self, name):
        return getattr(self.codec_context, name)
