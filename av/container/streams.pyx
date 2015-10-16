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

    def get(self, streams=None, **typed):

        selection = []

        if isinstance(streams, Stream):
            selection.append(streams)
        elif isinstance(streams, (tuple, list)):
            for x in streams:
                if isinstance(x, Stream):
                    selection.append(x)
                elif isinstance(x, int):
                    selection.append(self._streams[x])
                else:
                    raise TypeError('streams element must be Stream or int')
        elif streams is not None:
            raise TypeError('streams must be Stream or tuple')

        for type_, indices in typed.iteritems():
            streams = getattr(self, type_)
            if not isinstance(indices, (tuple, list)):
                indices = [indices]
            for i in indices:
                selection.append(streams[i])

        return selection or self._streams[:]


