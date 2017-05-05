Hacking on PyAV
===============

The Real Goal
-------------

The goal here is to not only wrap ffmpeg in Python and provide nearly complete
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
will have either ``PYAV_HAVE_LIBSWRESAMPLE`` or ``PYAV_HAVE_LIBAVRESAMPLE``.


Function Detection
------------------

Macros will be defined for a few functions that are only in one of FFmpeg or
LibAV. For example, there may be a ``PYAV_HAVE_AVFORMAT_CLOSE_INPUT`` macro.
See the ``reflect`` command in ``setup.py`` to add more.


Struct Member Detection
-----------------------

Macros will be defined for structure members that are not garunteed to exist
(usually because LibAV deprecated and removed them, while FFmpeg did not).
For example, there may be a ``PYAV_HAVE_AVFRAME__MB_TYPE`` macro if the
``AVFrame.mb_type`` member exists.


Class Relationships
-------------------

- ``Context.streams`` is a list of ``Stream``.
- ``Packet.stream`` is the ``Stream`` that it is from.
- ``Frame`` has no relationships in Python space.


Time in Libraries
-----------------

Time is usually represented as fractions; there is often a ``uint64_t pts`` or
``dts`` variable in `AVRational time_base` units.

Both ``AVStream`` and ``AVCodecContext`` have a time_base. While encoding, they
are for the ``AVPacket`` and ``AVFrame`` times respectively. However, while
decoding all times are in ``AVStream.time_base``.

TODO: I have seen the decode time_base be different in the codec_context JPEG
	  sequence tests!

When there is no time_base (such as on ``AVFormatContext``), there is an
implicit time_base of ``1/AV_TIME_BASE``.


Debugging
---------

```
./configure --with-pydebug --with-pymalloc
make -j12
```

