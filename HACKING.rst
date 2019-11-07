Hacking on PyAV
===============

The Goal
--------

The goal of PyAV is to not only wrap FFmpeg in Python and provide complete access to the library for power users, but to make FFmpeg approachable without the need to understand all of the underlying mechanics.

As much as reasonable, PyAV mirrors FFmpeg's structure and naming. Ideally, searching for documentation for `CodecContext.bit_rate` leads to `AVCodecContext.bit_rate` as well.

We do allow ourselves to make some small naming changes to make everything feel more consistent. e.g. All of the audio classes are prefixed with `Audio`, while some of the underlying FFmpeg structs are prefixed with `Sample` (`AudioFormat` vs `AVSampleFormat`).


Version Compatibility
---------------------

We currently support FFmpeg 4.0 through 4.2, on Python 2.7 and 3.3 through 3.7, on Linux, macOS, and Windows. We `continually test <https://github.com/mikeboers/PyAV/actions>`_  these configurations.

Differences are handled at compile time, in C, by checking against `LIBAV*_VERSION_INT` macros. We have not been able to perform this sort of checking in Cython as we have not been able to have it fully remove the code-paths, and so there are missing functions in newer FFmpeg's, and deprecated ones that emit compiler warnings in older FFmpeg's.

Unfortunately, this means that PyAV is built for the existing FFmpeg, and must be rebuilt when FFmpeg is updated.

We used to do this detection in small `*.pyav.h` headers in the `include` directory (and there are still some there as of writing), but the preferred method is to create `*-shims.c` files that are `cimport`-ed by the one module that uses them.

You can use the same build system as Travis for local development::

    # Prep the environment.
    source scripts/activate.sh

    # Build FFmpeg.
    ./scripts/build-deps

    # Build PyAV.
    make

    # Run the tests.
    make test


Code Formatting and Linting
---------------------------

``isort`` and ``flake8`` are integrated into the continuous integration, and are required to pass for code to be merged into develop. You can run these via ``scripts/test``::

    ./scripts/test isort
    ./scripts/test flake8


