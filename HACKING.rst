Hacking on PyAV
===============

The Goal
--------

The goal of PyAV is to not only wrap FFmpeg in Python and provide complete access to the library for power users, but to make FFmpeg approachable without the need to understand all of the underlying mechanics.

As much as reasonable, PyAV mirrors FFmpeg's structure and naming. Ideally, searching for documentation for `CodecContext.bit_rate` leads to `AVCodecContext.bit_rate` as well.

We do allow ourselves to make some small naming changes to make everything feel more consistent. e.g. All of the audio classes are prefixed with `Audio`, while some of the underlying FFmpeg structs are prefixed with `Sample` (`AudioFormat` vs `AVSampleFormat`).


Version Compatibility
---------------------

We currently support FFmpeg 3.2 through 4.0, on Python 2.7 and 3.3 through 3.7, on Linux, macOS, and Windows. We `continually test <https://travis-ci.org/mikeboers/PyAV>`_  these configurations.

Differences are handled at compile time, in C, by checking against `LIBAV*_VERSION_INT` macros. We have not been able to perform this sort of checking in Cython as we have not been able to have it fully remove the code-paths, and so there are missing functions in newer FFmpeg's, and deprecated ones that emit compiler warnings in older FFmpeg's.

Unfortunately, this means that PyAV is built for the existing FFmpeg, and must be rebuilt when FFmpeg is updated.

We used to do this detection in small `*.pyav.h` headers in the `include` directory (and there are still some there as of writing), but the preferred method is to create `*-shims.c` files that are `cimport`-ed by the one module that uses them.

You can use the same build system as Travis for local development::

    # Prep the environment.
    source scripts/activate.sh

    # Build FFmpeg (4.0 by default).
    ./scripts/build-deps

    # Build PyAV.
    make

    # Run the tests.
    make test


Time in Libraries
-----------------

.. note::

    Time in the underlying libraries is not 100% clear. This is the picture that we are operating under, however.

Time is expressed as integer multiples of defined units of time. The definition of a unit of time is called a ``time_base``.

Both ``AVStream`` and ``AVCodecContext`` have a ``time_base`` member. However, they are used for different purposes, and (this author finds) it is too easy to abstract the concept too far.

For encoding, you (the library user) must set ``AVCodecContext.time_base``, ideally to the inverse of the frame rate (or so the library docs say to do if your frame rate is fixed; we're not sure what to do if it is not fixed), and you may set ``AVStream.time_base`` as a hint to the muxer. After you open all the codecs and call ``avformat_write_headers``, the stream time base may change, and you must respect it. We don't know if the codec time base may change, so we will make the safer assumption that it may and respect it as well.

You then prepare ``AVFrame.pts`` in ``AVCodecContext.time_base``. The encoded ``AVPacket.pts`` is simply copied from the frame by the library, and so is still in the codec's time base. You must rescale it to ``AVStream.time_base`` before muxing (as all stream operations assume the packet time is in stream time base).

For fixed-fps content your frames' ``pts`` would be the frame or sample index (for video and audio, respectively). PyAV should attempt to do this.

For decoding, everything is in ``AVStream.time_base`` because we don't have to rebase it into codec time base (as it generally seems to be the case that ``AVCodecContext`` doesn't really care about your timing; I wish there was a way to assert this without reading every codec).

When there is no time_base (such as on ``AVFormatContext``), there is an implicit time_base of ``1/AV_TIME_BASE``.


Code Formatting and Linting
---------------------------

There is a ``scripts/autolint -a`` which will automatically perform a number of code linting operations. Pull requests are expected to adhere to what the linter does.


Debugging
---------

.. todo:: Explain.

```
./scripts/build-debug-python
```

