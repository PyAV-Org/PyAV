
.. _time:

Time
====

Overview
--------

Time is expressed as integer multiples of arbitrary units of time called a ``time_base``. There are different contexts that have different time bases: :class:`.Stream` has :attr:`.Stream.time_base`, :class:`.CodecContext` has :attr:`.CodecContext.time_base`, and :class:`.Container` has :data:`av.TIME_BASE`.

.. testsetup::

    import av
    path = av.datasets.curated('pexels/time-lapse-video-of-night-sky-857195.mp4')

    def get_nth_packet_and_frame(fh, skip):
        for p in fh.demux():
            for f in p.decode():
                if not skip:
                    return p, f
                skip -= 1

.. doctest::

    >>> fh = av.open(path)
    >>> video = fh.streams.video[0]

    >>> video.time_base
    Fraction(1, 25)

Attributes that represent time on those objects will be in that object's ``time_base``:

.. doctest::

    >>> video.duration
    168
    >>> float(video.duration * video.time_base)
    6.72

:class:`.Packet` has a :attr:`.Packet.pts` and :attr:`.Packet.dts` ("presentation" and "decode" time stamps), and :class:`.Frame` has a :attr:`.Frame.pts` ("presentation" time stamp). Both have a ``time_base`` attribute, but it defaults to the time base of the object that handles them. For packets that is streams. For frames it is streams when decoding, and codec contexts when encoding (which is strange, but it is what it is).

In many cases a stream has a time base of ``1 / frame_rate``, and then its frames have incrementing integers for times (0, 1, 2, etc.). Those frames take place at ``pts * time_base`` or ``0 / frame_rate``, ``1 / frame_rate``, ``2 / frame_rate``, etc..

.. doctest::

    >>> p, f = get_nth_packet_and_frame(fh, skip=1)

    >>> p.time_base
    Fraction(1, 25)
    >>> p.dts
    1

    >>> f.time_base
    Fraction(1, 25)
    >>> f.pts
    1


For convenience, :attr:`.Frame.time` is a ``float`` in seconds:

.. doctest::

    >>> f.time
    0.04


FFmpeg Internals
----------------

.. note:: Time in FFmpeg is not 100% clear to us (see :ref:`authority_of_docs`). At times the FFmpeg documentation and canonical seeming posts in the forums appear contradictory. We've experimented with it, and what follows is the picture that we are operating under.

Both :ffmpeg:`AVStream` and :ffmpeg:`AVCodecContext` have a ``time_base`` member. However, they are used for different purposes, and (this author finds) it is too easy to abstract the concept too far.

When there is no ``time_base`` (such as on :ffmpeg:`AVFormatContext`), there is an implicit ``time_base`` of ``1/AV_TIME_BASE``.

Encoding
........


For encoding, you (the PyAV developer / FFmpeg "user") must set :ffmpeg:`AVCodecContext.time_base`, ideally to the inverse of the frame rate (or so the library docs say to do if your frame rate is fixed; we're not sure what to do if it is not fixed), and you may set :ffmpeg:`AVStream.time_base` as a hint to the muxer. After you open all the codecs and call :ffmpeg:`avformat_write_header`, the stream time base may change, and you must respect it. We don't know if the codec time base may change, so we will make the safer assumption that it may and respect it as well.

You then prepare :ffmpeg:`AVFrame.pts` in :ffmpeg:`AVCodecContext.time_base`. The encoded :ffmpeg:`AVPacket.pts` is simply copied from the frame by the library, and so is still in the codec's time base. You must rescale it to :ffmpeg:`AVStream.time_base` before muxing (as all stream operations assume the packet time is in stream time base).

Decoding
........

Everything is in :ffmpeg:`AVStream.time_base` because we don't have to rebase it into codec time base (as it generally seems to be the case that :ffmpeg:`AVCodecContext` doesn't really care about your timing; I wish there was a way to assert this without reading every codec).

