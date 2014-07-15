Hacking on PyAV
===============

The Real Goal
-------------

The goal here is to not only wrap ffmpeg in Python and provide nearly complete access to the library, but to make it easier to use without the need to understand the full library.

For example:

- we don't need to mimick the underlying project structure as much as we do;
- we shouldn't be exposing audio attributes on a video codec, and vise-versa;
- the concept of packets could be abtracted away to yielding frames from streams;
- time should be a real number, instead of a rational;
- ...


FFmpeg vs Libav
---------------

Right now we ctypes-based discovery to determine what functions are availible, and some very small shim headers to smooth out the differences. Do try to test all changes on platforms which default to both libraries.


Library Detection
-----------------

Macros will be defined for the libraries we link against. In particular, you
will have either `PYAV_HAVE_LIBSWRESAMPLE` or `PYAV_HAVE_LIBAVRESAMPLE`.


Function Detection
------------------

Macros will be defined for a few functions that are only in one of FFmpeg or
LibAV. For example, there may be a `PYAV_HAVE_AVFORMAT_CLOSE_INPUT` macro.
See where `check_for_func` is used in `setup.py` to add more.


Class Relationships
-------------------

- `Context.streams` is a list of `Stream`.
- `Packet.stream` is the `Stream` that it is from.
- `Frame` has no relationships in Python space.

