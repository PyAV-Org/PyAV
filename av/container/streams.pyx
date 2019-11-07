
cimport libav as lib


def _flatten(input_):
    for x in input_:
        if isinstance(x, (tuple, list)):
            for y in _flatten(x):
                yield y
        else:
            yield x


cdef class StreamContainer(object):

    """

    A tuple-like container of :class:`Stream`.

    ::

        # There are a few ways to pulling out streams.
        first = container.streams[0]
        video = container.streams.video[0]
        audio = container.streams.get(audio=(0, 1))


    """

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
        if isinstance(index, int):
            return self.get(index)[0]
        else:
            return self.get(index)

    def get(self, *args, **kwargs):
        """get(streams=None, video=None, audio=None, subtitles=None, data=None)

        Get a selection of :class:`.Stream` as a ``list``.

        Positional arguments may be ``int`` (which is an index into the streams),
        or ``list`` or ``tuple`` of those::

            # Get the first channel.
            streams.get(0)

            # Get the first two audio channels.
            streams.get(audio=(0, 1))

        Keyword arguments (or dicts as positional arguments) as interpreted
        as ``(stream_type, index_value_or_set)`` pairs::

            # Get the first video channel.
            streams.get(video=0)
            # or
            streams.get({'video': 0})

        :class:`.Stream` objects are passed through untouched.

        If nothing is selected, then all streams are returned.

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
                for type_, indices in x.items():
                    if type_ == 'streams':  # For compatibility with the pseudo signature
                        streams = self._streams
                    else:
                        streams = getattr(self, type_)
                    if not isinstance(indices, (tuple, list)):
                        indices = [indices]
                    for i in indices:
                        selection.append(streams[i])

            else:
                raise TypeError('Argument must be Stream or int.', type(x))

        return selection or self._streams[:]
