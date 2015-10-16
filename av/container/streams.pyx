cimport libav as lib

cdef class StreamContainer(object):

    def __cinit__(self):
        self._streams = []
        self.video = ()
        self.audio = ()
        self.subtitles = ()
        self.other = ()

    cdef add_stream(self, Stream stream):

        assert stream._stream.index == len(self._streams)
        self._streams.append(stream)

        if stream._codec_context.codec_type == lib.AVMEDIA_TYPE_VIDEO:
            self.video = self.video + (stream, )
        elif stream._codec_context.codec_type == lib.AVMEDIA_TYPE_AUDIO:
            self.audio = self.audio + (stream, )
        elif stream._codec_context.codec_type == lib.AVMEDIA_TYPE_SUBTITLE:
            self.subtitles = self.subtitles + (stream, )
        else:
            self.other = self.other + (stream, )

    # Basic tuple interface.
    def __len__(self):
        return len(self._streams)
    def __iter__(self):
        return iter(self._streams)
    def __getitem__(self, index):
        return self._streams[index]

