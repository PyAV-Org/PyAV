pyav-ffmpeg
===========

This project provides binary builds of FFmpeg and its dependencies for `PyAV`_.
These builds are used in order to provide binary wheels of PyAV, allowing
users to easily install PyAV without perform error-prone compilations.

The builds are provided for several platforms:

- Linux (x86_64, i686, aarch64, ppc64le)
- macOS (x86_64, arm64)
- Windows (AMD64)

Features
--------

Currently FFmpeg 4.4.1 is used with the following features enabled for all platforms:

- fontconfig
- gmp
- gnutls
- libaom
- libass
- libbluray
- libdav1d
- libfreetype
- libmp3lame
- libopencore-amrnb
- libopencore-amrwb
- libopenjpeg
- libopus
- libspeex
- libtheora
- libtwolame
- libvorbis
- libvpx
- libx264
- libx265
- libxml2
- libxvid
- lzma
- zlib

.. _PyAV: https://github.com/PyAV-Org/PyAV
