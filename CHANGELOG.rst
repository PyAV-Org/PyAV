Changelog
=========

We are operating with `semantic versioning <http://semver.org>`_.


v6.0.0.dev0
-----------

Major:

- Drop support for FFmpeg < 3.2.

Minor:

- Add support for more image formats in :meth:`.VideoFrame.to_ndarray` and
  :meth:`VideoFrame.from_ndarray` (:issue:`415`).
- Add support for all known sample formats in :meth:`AudioFrame.to_ndarray`
  and add :meth:`AudioFrame.to_ndarray` (:issue:`422`).
- Make all video frames created by PyAV use 8-byte alignment.
- Fix manipulations on video frames whose width does not match the line stride
  (:issue:`423`).
- Remove :meth:`.VideoFrame.to_qimage` method, it is too tied to PyQt4
  (:issue:`424`).
- Ensure :meth:`OutputContainer.close` is called at destruction (:issue:`427`).
- Fix a memory leak in :class:`.OutputContainer` initialisation (:issue:`427`).

Build:

- Remove the "reflection" mechanism, and rely on FFmpeg version we build
  against to decide which methods to call (:issue:`416`).

v0.x.y
------

.. note::

    Below here we used ``v0.x.y``.

    We incremented ``x`` to signal a major change (i.e. backwards
    incompatibilities) and incremented ``y`` as a minor change (i.e. backwards
    compatible features).

    Once we wanted more subtlety and felt we had matured enough, we jumped
    past the implications of ``v1.0.0`` straight to ``v6.0.0``
    (as if we had not been stuck in ``v0.x.y`` all along).


v0.5.3
------

Minor:

- Expose :attr:`.VideoFrame.pict_type` as :class:`.PictureType` enum.
  (:pr:`402`)
- Expose :attr:`.Codec.video_rates` and :attr:`.Codec.audio_rates`.
  (:pr:`381`)

Patch:

- Fix :attr:`.Packet.time_base` handling during flush.
  (:pr:`398`)
- :meth:`.VideoFrame.reformat` can throw exceptions when requested colorspace
  transforms aren't possible.
- Wrapping the stream object used to overwrite the ``pix_fmt`` attribute.
  (:pr:`390`)

Runtime:

- Deprecate ``VideoFrame.ptr`` in favour of :attr:`VideoFrame.buffer_ptr`.
- Deprecate ``Plane.update_buffer()`` and ``Packet.update_buffer`` in favour of
  :meth:`.Plane.update`.
  (:pr:`407`)
- Deprecate ``Plane.update_from_string()`` in favour of :meth:`.Plane.update`.
  (:pr:`407`)
- Deprecate ``AudioFrame.to_nd_array()`` and ``VideoFrame.to_nd_array()`` in
  favour of :meth:`.AudioFrame.to_ndarray` and :meth:`.VideoFrame.to_ndarray`.
  (:pr:`404`)

Build:

- CI covers more cases, including macOS.
  (:pr:`373` and :pr:`399`)
- Fix many compilation warnings.
  (:issue:`379`, :pr:`380`, :pr:`387`, and :pr:`388`)

Docs:

- Docstrings for many commonly used attributes.
  (:pr:`372` and :pr:`409`)


v0.5.2
------

Build:

- Fixed Windows build, which broke in v0.5.1.
- Compiler checks are not cached by default. This behaviour is retained if you
  ``source scripts/activate.sh`` to develop PyAV.
  (:issue:`256`)
- Changed to ``PYAV_SETUP_REFLECT_DEBUG=1`` from ``PYAV_DEBUG_BUILD=1``.


v0.5.1
------

Build:

- Set ``PYAV_DEBUG_BUILD=1`` to force a verbose reflection (mainly for being
  installed via ``pip``, which is why this is worth a release).


v0.5.0
------

Major:

- Dropped support for Libav in general.
  (:issue:`110`)
- No longer uses libavresample.

Minor:

- ``av.open`` has ``container_options`` and ``stream_options``.
- ``Frame`` includes ``pts`` in ``repr``.

Fixes:

- EnumItem's hash calculation no longer overflows.
  (:issue:`339`, :issue:`341` and :issue:`342`.)
- Frame.time_base was not being set in most cases during decoding.
  (:issue:`364`)
- CodecContext.options no longer needs to be manually initialized.
- CodexContext.thread_type accepts its enums.


v0.4.1
------

Minor:

- Add `Frame.interlaced_frame` to indicate if the frame is interlaced.
  (:issue:`327` by :gh-user:`MPGek`)
- Add FLTP support to ``Frame.to_nd_array()``.
  (:issue:`288` by :gh-user:`rawler`)
- Expose ``CodecContext.extradata`` for codecs that have extra data, e.g.
  Huffman tables.
  (:issue:`287` by :gh-user:`adavoudi`)

Fixes:

- Packets retain their refcount after muxing.
  (:issue:`334`)
- `Codec` construction is more robust to find more codecs.
  (:issue:`332` by :gh-user:`adavoudi`)
- Refined frame corruption detection.
  (:issue:`291` by :gh-user:`Litterfeldt`)
- Unicode filenames are okay.
  (:issue:`82`)


v0.4.0
------

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

- Added ``Packet.is_keyframe`` and ``Packet.is_corrupt``.
  (:issue:`226`)
- Many more ``time_base``, ``pts`` and other attributes are writeable.
- ``Option`` exposes much more of the API (but not get/set).
  (:issue:`243`)
- Expose metadata encoding controls.
  (:issue:`250`)
- Expose ``CodecContext.skip_frame``.
  (:issue:`259`)

Fixes:

- Build doesn't fail if you don't have git installed.
  (:issue:`184`)
- Developer environment works better with Python3.
  (:issue:`248`)
- Fix Container deallocation resulting in segfaults.
  (:issue:`253`)


v0.3.3
------

Fixes:

- Fix segfault due to buffer overflow in handling of stream options.
  (:issue:`163` and :issue:`169`)
- Fix segfault due to seek not properly checking if codecs were open before
  using avcodec_flush_buffers.
  (:issue:`201`)


v0.3.2
------

Minor:

- Expose basics of avfilter via ``Filter``.
- Add ``Packet.time_base``.
- Add ``AudioFrame.to_nd_array`` to match same on ``VideoFrame``.
- Update Windows build process.

Fixes:

- Further improvements to the logging system.
  (:issue:`128`)


v0.3.1
------

Minor:

- ``av.logging.set_log_after_shutdown`` renamed to ``set_print_after_shutdown``
- Repeating log messages will be skipped, much like ffmpeg's does by default

Fixes:

- Fix memory leak in logging system when under heavy logging loads while
  threading.
  (:issue:`128` with help from :gh-user:`mkassner` and :gh-user:`ksze`)


v0.3.0
------

Major:

- Python IO can write
- Improve build system to use Python's C compiler for function detection;
  build system is much more robust
- MSVC support.
  (:issue:`115` by :gh-user:`vidartf`)
- Continuous integration on Windows via AppVeyor. (by :gh-user:`vidartf`)

Minor:

- Add ``Packet.decode_one()`` to skip packet flushing for codecs that would
  otherwise error
- ``StreamContainer`` for easier selection of streams
- Add buffer protocol support to Packet

Fixes:

- Fix bug when using Python IO on files larger than 2GB.
  (:issue:`109` by :gh-user:`xxr3376`)
- Fix usage of changed Pillow API

Known Issues:

- VideoFrame is suspected to leak memory in narrow cases on Linux.
  (:issue:`128`)


v0.2.4
------

- fix library search path for current Libav/Ubuntu 14.04.
  (:issue:`97`)
- explicitly include all sources to combat 0.2.3 release problem.
  (:issue:`100`)


v0.2.3
------

.. warning:: There was an issue with the PyPI distribution in which it required
    Cython to be installed.

Major:

- Python IO.
- Agressively releases GIL
- Add experimental Windows build.
  (:issue:`84`)

Minor:

- Several new Stream/Packet/Frame attributes

Fixes:

- Fix segfault in audio handling.
  (:issue:`86` and :issue:`93`)
- Fix use of PIL/Pillow API.
  (:issue:`85`)
- Fix bad assumptions about plane counts.
  (:issue:`76`)


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
