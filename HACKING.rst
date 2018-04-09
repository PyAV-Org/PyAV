Hacking on PyAV
===============

The Real Goal
-------------

The goal here is to not only wrap FFmpeg in Python and provide nearly complete
access to the library, but to make it easier to use without the need to
understand the full library.

For example:

- we don't need to mimick the underlying project structure as much as we do;
- we shouldn't be exposing audio attributes on a video codec, and vise-versa;
- the concept of packets could be abtracted away to yielding frames from streams;
- time should be a real number, instead of a rational;
- ...


FFmpeg vs Libav
---------------

We test compile and link tiny executables to determine what functions and
structure members are availible, and some very small shim headers to smooth
out the differences.

We `continually test <https://travis-ci.org/mikeboers/PyAV>`_ multiple versions
of FFmpeg/Libav, as well as Linux/OS X, and Python 2/3.

You can use the same build system as Travis for local development::

    source scripts/activate.sh ffmpeg 2.7
    ./scripts/build-deps
    make
    nosetests


Library Detection
-----------------

Macros will be defined for the libraries we link against. In particular, you
will have ``PYAV_HAVE_LIBSWRESAMPLE`` and ``PYAV_HAVE_LIBAVRESAMPLE`` defined
to either ``0`` or ``1``.


Function Detection
------------------

Macros will be defined for a few functions that are only in one of FFmpeg or
LibAV. For example, there is a ``PYAV_HAVE_AVFORMAT_CLOSE_INPUT`` macro defined
to either ``0`` or ``1``.

See the ``reflect`` command in ``setup.py`` to add more.


Struct Member Detection
-----------------------

Macros will be defined for structure members that are not garunteed to exist
(usually because LibAV deprecated and removed them, while FFmpeg did not).
For example, there is a ``PYAV_HAVE_AVFRAME__MB_TYPE`` macro defined to ``1``
if the ``AVFrame.mb_type`` member exists (and ``0`` if it does not).


Time in Libraries
-----------------

.. note::

    Time in the underlying libraries is not 100% clear. This is the picture that we are operating under, however.

Time is generally expressed as integer multiples of defined units of time. The definition of a unit of time is called a ``time_base``.

Both ``AVStream`` and ``AVCodecContext`` have a ``time_base`` member. However, they are used for different purposes, and (this author finds) it is too easy to abstract the concept too far.

For encoding, you (the library user) must set ``AVCodecContext.time_base``, ideally to the inverse of the frame rate (or so the library docs say to do if your frame rate is fixed; we're not sure what to do if it is not fixed), and you may set ``AVStream.time_base`` as a hint to the muxer. After you open all the codecs and call ``avformat_write_headers``, the stream time base may change, and you must respect it. We don't know if the codec time base may change, so we will make the safer assumption that it may and respect it as well.

You then prepare ``AVFrame.pts`` in ``AVCodecContext.time_base``. The encoded ``AVPacket.pts`` is simply copied from the frame by the library, and so is still in the codec's time base. You must rescale it to ``AVStream.time_base`` before muxing (as all stream operations assume the packet time is in stream time base).

For fixed-fps content your frames' ``pts`` would be the frame or sample index (for video and audio, respectively). PyAV should attempt to do this.

For decoding, everything is in ``AVStream.time_base`` because we don't have to rebase it into codec time base (as it generally seems to be the case that ``AVCodecContext`` doesn't really care about your timing; I wish there was a way to assert this without reading every codec).

When there is no time_base (such as on ``AVFormatContext``), there is an
implicit time_base of ``1/AV_TIME_BASE``.


Code Formatting and Linting
---------------------------

There is a ``scripts/autolint -a`` which will automatically perform a number of
code linting operations. Pull requests are expected to adhere to what the
linter does.


Debugging
---------

.. todo:: Explain.

```
./scripts/build-debug-python
```

