cimport libav as lib


def _flatten(input_):
    for x in input_:
        if isinstance(x, (tuple, list)):
            for y in _flatten(x):
                yield y
        else:
            yield x


cdef class StreamContainer(object):

    def __cinit__(self):
        self._streams = []
        self.video = ()
        self.audio = ()
        self.subtitles = ()
        self.data = ()
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
        elif stream._codec_context.codec_type == lib.AVMEDIA_TYPE_DATA:
            self.data = self.data + (stream, )
        else:
            self.other = self.other + (stream, )

    # Basic tuple interface.
    def __len__(self):
        return len(self._streams)
    def __iter__(self):
        return iter(self._streams)
    def __getitem__(self, index):
        return self._streams[index]

    def get(self, *args, **kwargs):
        """Get a selection of streams.

        Keyword arguments (or dicts as positional arguments) as interpreted
        as ``(stream_type, index_value_or_set)`` pairs.

        Positional arguments may be given as :class:`Stream` objects (which
        are passed through), ``int`` (which is an index into the streams), or
        ``list`` or ``tuple`` of those.

        If nothing is selected, then all streams are returned.

        e.g.::

            # Get the first channel.
            streams.get(0)

            # Get the first video channel.
            streams.get(video=0)
            # or
            streams.get({'video': 0})

            # Get the first two audio channels.
            streams.get(audio=(0, 1))


        """
        selection = []

        for x in _flatten((args, kwargs)):

            if x is None:
                pass

            elif isinstance(x, Stream):
                selection.append(x)

            elif isinstance(x, int):
                selection.append(self._streams[x])

            elif isinstance(x, dict):
                for type_, indices in x.iteritems():
                    streams = getattr(self, type_)
                    if not isinstance(indices, (tuple, list)):
                        indices = [indices]
                    for i in indices:
                        selection.append(streams[i])

            else:
                raise TypeError('Argument must be Stream or int.', type(x))

        return selection or self._streams[:]
