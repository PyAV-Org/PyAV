More About PyAV
===============

Binary wheels
-------------

Since release 8.0.0 binary wheels are provided on PyPI for Linux, Mac and Windows linked against FFmpeg. Currently FFmpeg 4.2.2 is used with the following features enabled for all platforms:

- fontconfig
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
- libwavpack
- libx264
- libx265
- libxml2
- libxvid
- lzma
- zlib

Bring your own FFmpeg
---------------------

PyAV can also be compiled against your own build of FFmpeg. While it must be built for the specific FFmpeg version installed it does not require a specific version. You can force installing PyAV from source by running:

```
pip install av --no-binary av
```

We automatically detect the differences that we depended on at build time. This is a fairly trial-and-error process, so please let us know if something won't compile due to missing functions or members.

Additionally, we are far from wrapping the full extents of the libraries. There are many functions and C struct members which are currently unexposed.


Dropping Libav
--------------

Until mid-2018 PyAV supported either FFmpeg_ or Libav_. The split support in the community essentially required we do so. That split has largely been resolved as distributions have returned to shipping FFmpeg instead of Libav.

While we could have theoretically continued to support both, it has been years since automated testing of PyAV with Libav passed, and we received zero complaints. Supporting both also restricted us to using the subset of both, which was starting to erode at the cleanliness of PyAV.

Many Libav-isms remain in PyAV, and we will slowly scrub them out to clean up PyAV as we come across them again.


Unsupported Features
--------------------

Our goal is to provide all of the features that make sense for the contexts that PyAV would be used in. If there is something missing, please reach out on Gitter_ or open a feature request on GitHub_ (or even better a pull request). Your request will be more likely to be addressed if you can point to the relevant `FFmpeg API documentation <https://ffmpeg.org/doxygen/trunk/index.html>`__.

There are some features we may elect to not implement because we don't believe they fit the PyAV ethos. The only one that we've encountered so far is hardware decoding. The `FFmpeg man page <https://ffmpeg.org/ffmpeg.html>`__ discusses the drawback of ``-hwaccel``:

    Note that most acceleration methods are intended for playback and will not be faster than software decoding on modern CPUs. Additionally, ``ffmpeg`` will usually need to copy the decoded frames from the GPU memory into the system memory, resulting in further performance loss.

Since PyAV is not expected to be used in a high performance playback loop, we do not find the added code complexity worth the benefits of supporting this feature


.. _FFmpeg: https://ffmpeg.org/
.. _Libav: https://libav.org/

.. _Gitter: https://gitter.im/PyAV-Org
.. _GitHub: https://github.com/PyAV-Org/pyav
