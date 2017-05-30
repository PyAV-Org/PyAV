More About PyAV
===============

FFmpeg vs Libav
---------------

We are attempting to write this wrapper to work with either FFmpeg_ or Libav_.
We automatically detect the differences that we have determined exist as this
wrapper is being developed. This is a fairly trial-and-error process, so please
let us know if there are any odd compiler errors or something won't link due to
missing functions.

Additionally, we are far from wrapping the full extents of the libraries.
There are many functions and C struct members which are currently unexposed.

.. _FFmpeg: http://ffmpeg.org
.. _Libav: http://libav.org

