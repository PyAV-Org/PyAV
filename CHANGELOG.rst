Changelog
=========

We are operating with semantic versioning <http://semver.org/>. However,
we are using v0.x.y as our heavy development period, and will increment ``x``
to signal a major change (i.e. backwards incompatibilities) and increment
``y`` as a minor change (i.e. backwards compatible features).


v0.4.0.dev0
-----------

Major:

- ``CodecContext`` has taken over encoding/decoding, and can work in isolation
  of streams/containers.
- ``Stream.encode`` returns a list of packets, instead of a single packet.
- ``AudioFifo`` and ``AudioResampler`` will raise ``ValueError`` if input frames
  inconsistant ``pts``.
- ``time_base`` use has been revisited across the codebase, and may not be converted
  bettween ``Stream.time_base`` and ``CodecContext.time_base`` at the same times
  in the transcoding pipeline.
- ``CodecContext.rate`` has been removed, but proxied to ``VideoCodecContext.framerate``
  and ``AudioCodecContext.sample_rate``. The definition is effectively inverted from
  the old one (i.e. for 24fps it used to be ``1/24`` and is now ``24/1``).
- Fractions (e.g. ``time_base``, ``rate``) will be ``None`` if they are invalid.
- ``InputContainer.seek`` and ``Stream.seek`` will raise TypeError if given
  a float, when previously they converted it from seconds.

Minor:

- Added ``Packet.is_keyframe`` and ``Packet.is_corrupt`` (#226).
- Many more ``time_base``, ``pts`` and other attributes are writeable.
- ``Option`` exposes much more of the API (but not get/set) (#243).
- Expose metadata encoding controls (#250).
- Expose ``CodecContext.skip_frame`` (#259).

Fixes:

- Build doesn't fail if you don't have git installed (#184).
- Developer environment works better with Python3 (#248).
- Fix Container deallocation resulting in segfaults (#253).


v0.3.3
------

Fixes:

- Fix segfault due to buffer overflow in handling of stream options.
  (#163 and #169.)
- Fix segfault due to seek not properly checking if codecs were open before
  using avcodec_flush_buffers. (#201.)


v0.3.2
------

Minor:

- Expose basics of avfilter via ``Filter``.
- Add ``Packet.time_base``.
- Add ``AudioFrame.to_nd_array`` to match same on ``VideoFrame``.
- Update Windows build process.

Fixes:

- Further improvements to the logging system, continued from #128.


v0.3.1
------

Minor:

- ``av.logging.set_log_after_shutdown`` renamed to ``set_print_after_shutdown``
- Repeating log messages will be skipped, much like ffmpeg's does by default

Fixes:

- Fix memory leak in logging system when under heavy logging loads while
  threading (#128 with help from @mkassner and @ksze)


v0.3.0
------

Major:

- Python IO can write
- Improve build system to use Python's C compiler for function detection;
  build system is much more robust
- MSVC support (#115 by @vidartf)
- Continuous integration on Windows via AppVeyor (by @vidartf)

Minor:

- Add ``Packet.decode_one()`` to skip packet flushing for codecs that would
  otherwise error
- ``StreamContainer`` for easier selection of streams
- Add buffer protocol support to Packet

Fixes:

- Fix bug when using Python IO on files larger than 2GB (#109 by @xxr3376)
- Fix usage of changed Pillow API

Known Issues:

- VideoFrame is suspected to leak memory in narrow cases on Linux (#128)


v0.2.4
------

- fix library search path for current Libav/Ubuntu 14.04 (#97)
- explicitly include all sources to combat 0.2.3 release problem (#100)


v0.2.3
------

.. warning:: There was an issue with the PyPI distribution in which it required
    Cython to be installed.

Major:

- Python IO.
- Agressively releases GIL
- Add experimental Windows build (#84)

Minor:

- Several new Stream/Packet/Frame attributes

Fixes:

- Fix segfault in audio handling (#86 and #93)
- Fix use of PIL/Pillow API (#85)
- Fix bad assumptions about plane counts (#76)


v0.2.2
------

- Cythonization in setup.py; mostly a development issue.
- Fix for av.InputContainer.size over 2**31.


v0.2.1
------

- Python 3 compatibility!
- Build process fails if missing libraries.
- Fix linking of libavdevices.


v0.2.0
------

.. warning:: This version has an issue linking in libavdevices, and very likely
    will not work for you.

It sure has been a long time since this was released, and there was a lot of
arbitrary changes that come with us wrapping an API as we are discovering it.
Changes include, but are not limited to:

- Audio encoding.
- Exposing planes and buffers.
- Descriptors for channel layouts, video and audio formats, etc..
- Seeking.
- Many many more properties on all of the objects.
- Device support (e.g. webcams).


v0.1.0
------

- FIRST PUBLIC RELEASE!
- Container/video/audio formats.
- Audio layouts.
- Decoding video/audio/subtitles.
- Encoding video.
- Audio FIFOs and resampling.
