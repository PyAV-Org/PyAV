Changelog
=========

We are operating with `semantic versioning <http://semver.org>`_.

..
    Please try to update this file in the commits that make the changes.

    To make merging/rebasing easier, we don't manually break lines in here
    when they are too long, so any particular change is just one line.

    To make tracking easier, please add either ``closes #123`` or ``fixes #123``
    to the first line of the commit message. There are more syntaxes at:
    <https://blog.github.com/2013-01-22-closing-issues-via-commit-messages/>.

    Note that they these tags will not actually close the issue/PR until they
    are merged into the "default" branch, currently "develop").

v8.0.4.dev0
------


v8.0.3
------

Minor:

- Update FFmpeg to 4.3.1 for the binary wheels.

v8.0.2
------

Minor:

- Enable GnuTLS support in the FFmpeg build used for binary wheels (:issue:`675`).
- Make binary wheels compatible with Mac OS X 10.9+ (:issue:`662`).
- Drop Python 2.x buffer protocol code.
- Remove references to previous repository location.

v8.0.1
------

Minor:

- Enable additional FFmpeg features in the binary wheels.
- Use os.fsencode for both input and output file names (:issue:`600`).

v8.0.0
------

Major:

- Drop support for Python 2 and Python 3.4.
- Provide binary wheels for Linux, Mac and Windows.

Minor:

- Remove shims for obsolete FFmpeg versions (:issue:`588`).
- Add yuvj420p format for :meth:`VideoFrame.from_ndarray` and :meth:`VideoFrame.to_ndarray` (:issue:`583`).
- Add support for palette formats in :meth:`VideoFrame.from_ndarray` and :meth:`VideoFrame.to_ndarray` (:issue:`601`).
- Fix Python 3.8 deprecation warning related to abstract base classes (:issue:`616`).
- Remove ICC profiles from logos (:issue:`622`).

Fixes:

- Avoid infinite timeout in :func:`av.open` (:issue:`589`).

v7.0.1
------

Fixes:

- Removed deprecated ``AV_FRAME_DATA_QP_TABLE_*`` enums. (:issue:`607`)


v7.0.0
------

Major:

- Drop support for FFmpeg < 4.0. (:issue:`559`)
- Introduce per-error exceptions, and mirror the builtin exception hierarchy. It is recommended to examine your error handling code, as common FFmpeg errors will result in `ValueError` baseclasses now. (:issue:`563`)
- Data stream's `encode` and `decode` return empty lists instead of none allowing common API use patterns with data streams.
- Remove ``whence`` parameter from :meth:`InputContainer.seek` as non-time seeking doesn't seem to actually be supported by any FFmpeg formats.

Minor:

- Users can disable the logging system to avoid lockups in sub-interpreters. (:issue:`545`)
- Filters support audio in general, and a new :meth:`.Graph.add_abuffer`. (:issue:`562`)
- :func:`av.open` supports `timeout` parameters. (:issue:`480` and :issue:`316`)
- Expose :attr:`Stream.base_rate` and :attr:`Stream.guessed_rate`. (:issue:`564`)
- :meth:`.VideoFrame.reformat` can specify interpolation.
- Expose many sets of flags.

Fixes:

- Fix typing in :meth:`.CodecContext.parse` and make it more robust.
- Fix wrong attribute in ByteSource. (:issue:`340`)
- Remove exception that would break audio remuxing. (:issue:`537`)
- Log messages include last FFmpeg error log in more helpful way.
- Use AVCodecParameters so FFmpeg doesn't complain. (:issue:`222`)


v6.2.0
------

Major:

- Allow :meth:`av.open` to be used as a context manager.
- Fix compatibility with PyPy, the full test suite now passes. (:issue:`130`)

Minor:

- Add :meth:`.InputContainer.close` method. (:issue:`317`, :issue:`456`)
- Ensure audio output gets flushes when using a FIFO. (:issue:`511`)
- Make Python I/O buffer size configurable. (:issue:`512`)
- Make :class:`.AudioFrame` and :class:`VideoFrame` more garbage-collector friendly by breaking a reference cycle. (:issue:`517`)

Build:

- Do not install the `scratchpad` package.


v6.1.2
------

Micro:

- Fix a numpy deprecation warning in :meth:`.AudioFrame.to_ndarray`.


v6.1.1
------

Micro:

- Fix alignment in :meth:`.VideoFrame.from_ndarray`. (:issue:`478`)
- Fix error message in :meth:`.Buffer.update`.

Build:

- Fix more compiler warnings.


v6.1.0
------

Minor:

- ``av.datasets`` for sample data that is pulled from either FFmpeg's FATE suite, or our documentation server.
- :meth:`.InputContainer.seek` gets a ``stream`` argument to specify the ``time_base`` the requested ``offset`` is in.

Micro:

- Avoid infinite look in ``Stream.__getattr__``. (:issue:`450`)
- Correctly handle Python I/O with no ``seek`` method.
- Remove ``Datastream.seek`` override (:issue:`299`)

Build:

- Assert building against compatible FFmpeg. (:issue:`401`)
- Lock down Cython lanaguage level to avoid build warnings. (:issue:`443`)

Other:

- Incremental improvements to docs and tests.
- Examples directory will now always be runnable as-is, and embeded in the docs (in a copy-pastable form).


v6.0.0
------

Major:

- Drop support for FFmpeg < 3.2.
- Remove ``VideoFrame.to_qimage`` method, as it is too tied to PyQt4. (:issue:`424`)

Minor:

- Add support for all known sample formats in :meth:`.AudioFrame.to_ndarray` and add :meth:`.AudioFrame.to_ndarray`. (:issue:`422`)
- Add support for more image formats in :meth:`.VideoFrame.to_ndarray` and :meth:`.VideoFrame.from_ndarray`. (:issue:`415`)

Micro:

- Fix a memory leak in :meth:`.OutputContainer.mux_one`. (:issue:`431`)
- Ensure :meth:`.OutputContainer.close` is called at destruction. (:issue:`427`)
- Fix a memory leak in :class:`.OutputContainer` initialisation. (:issue:`427`)
- Make all video frames created by PyAV use 8-byte alignment. (:issue:`425`)
- Behave properly in :meth:`.VideoFrame.to_image` and :meth:`.VideoFrame.from_image` when ``width != line_width``. (:issue:`425`)
- Fix manipulations on video frames whose width does not match the line stride. (:issue:`423`)
- Fix several :attr:`.Plane.line_size` misunderstandings. (:issue:`421`)
- Consistently decode dictionary contents. (:issue:`414`)
- Always use send/recv en/decoding mechanism. This removes the ``count`` parameter, which was not used in the send/recv pipeline. (:issue:`413`)
- Remove various deprecated iterators. (:issue:`412`)
- Fix a memory leak when using Python I/O. (:issue:`317`)
- Make :meth:`.OutputContainer.mux_one` call `av_interleaved_write_frame` with the GIL released.

Build:

- Remove the "reflection" mechanism, and rely on FFmpeg version we build against to decide which methods to call. (:issue:`416`)
- Fix many more ``const`` warnings.


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

Patch:

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

Patch:

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

Patch:

- Build doesn't fail if you don't have git installed.
  (:issue:`184`)
- Developer environment works better with Python3.
  (:issue:`248`)
- Fix Container deallocation resulting in segfaults.
  (:issue:`253`)


v0.3.3
------

Patch:

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

Patch:

- Further improvements to the logging system.
  (:issue:`128`)


v0.3.1
------

Minor:

- ``av.logging.set_log_after_shutdown`` renamed to ``set_print_after_shutdown``
- Repeating log messages will be skipped, much like ffmpeg's does by default

Patch:

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

Patch:

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

Patch:

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
