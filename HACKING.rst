Hacking on PyAV
===============

The Goal
--------

The goal of PyAV is to not only wrap FFmpeg in Python and provide complete access to the library for power users, but to make FFmpeg approachable without the need to understand all of the underlying mechanics.


Names and Structure
-------------------

As much as reasonable, PyAV mirrors FFmpeg's structure and naming. Ideally, searching for documentation for ``CodecContext.bit_rate`` leads to ``AVCodecContext.bit_rate`` as well.

We allow ourselves to depart from FFmpeg to make everything feel more consistent, e.g.:

- we change a few names to make them more readable, by adding underscores, etc.;
- all of the audio classes are prefixed with ``Audio``, while some of the FFmpeg structs are prefixed with ``Sample`` (e.g. ``AudioFormat`` vs ``AVSampleFormat``).

We will also sometimes duplicate APIs in order to provide both a low-level and high-level experience, e.g.:

- Object flags are usually exposed as a :class:`av.enum.EnumFlag` (with FFmpeg names) under a ``flags`` attribute, **and** each flag is also a boolean attribute (with more Pythonic names).


Version Compatibility
---------------------

We currently support FFmpeg 4.0 through 4.2, on Python 3.5 through 3.8, on Linux, macOS, and Windows. We `continually test <https://github.com/PyAV-Org/PyAV/actions>`_  these configurations.

Differences are handled at compile time, in C, by checking against ``LIBAV*_VERSION_INT`` macros. We have not been able to perform this sort of checking in Cython as we have not been able to have it fully remove the code-paths, and so there are missing functions in newer FFmpeg's, and deprecated ones that emit compiler warnings in older FFmpeg's.

Unfortunately, this means that PyAV is built for the existing FFmpeg, and must be rebuilt when FFmpeg is updated.

We used to do this detection in small ``*.pyav.h`` headers in the ``include`` directory (and there are still some there as of writing), but the preferred method is to create ``*-shims.c`` files that are cimport-ed by the one module that uses them.

You can use the same build system as continuous integration for local development::

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


