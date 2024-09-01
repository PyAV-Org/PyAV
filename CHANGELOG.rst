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
    are merged into the "default" branch.

v13.0.0
-------

Major:

- Drop FFmpeg 5, Support FFmpeg 7.
- Drop Python 3.8, Support Python 3.13.
- Update FFmpeg to 7.0.2 for the binary wheels.
- Disallow initializing an AudioLayout object with an int.
- Disallow accessing gop_size, timebase as a decoder (Raised deprecation warning before).
- Remove `ticks_per_frame` property because it was deprecated in FFmpeg.

Features:

- Add AttachmentStream class.
- Add `best()` method to StreamContainer.
- Add `set_audio_frame_size()` method to Graph object.
- Add `nb_channels` property to AudioLayout object.

Fixes:

- Fix VideoCC's repl breaking when `self._format` is None.
- Fix getting `pix_fmt` property when VideoCC's `self._format` is None.

v12.3.0
-------

Features:

- Support libav's `av_log_set_level` by @materight in (:issue:`1448`).
- Add Graph.link_nodes by @WyattBlue in (:issue:`1449`).
- Add default codec properties by @WyattBlue in (:issue:`1450`).
- Remove the xvid and ass packages in ffmpeg binaries because they were unused by @WyattBlue in (:issue:`1462`).
- Add supported_codecs property to OutputContainer by @WyattBlue in (:issue:`1465`).
- Add text and dialogue property to AssSubtitle, remove TextSubtitle by @WyattBlue in (:issue:`1456`).

Fixes:

- Include libav headers in final distribution by @materight in (:issue:`1455`).
- Fix segfault when calling subtitle_stream.decode() by @WyattBlue in (:issue:`1460`).
- flushing subtitle decoder requires a new uninitialized packet by @moonsikpark in (:issue:`1461`).
- Set default color range for VideoReformatter.format() by @elxy in (:issue:`1458`).
- Resampler: format, layout accepts `str` `int` too by @WyattBlue in (:issue:`1446`).

v12.2.0
-------

Features:

- Add a `make_writable` method to `Frame` instances (:issue:`1414`).
- Use `av_guess_sample_aspect_ratio` to report sample and display aspect ratios.

Fixes:

- Fix a crash when assigning an `AudioLayout` to `AudioCodecContext.layout` (:issue:`1434`).
- Remove a circular reference which caused `AudioSampler` to occupy memory until garbage collected (:issue:`1429`).
- Fix more type stubs, remove incorrect `__init__.pyi`.

v12.1.0
-------

Features:

- Build binary wheels with webp support.
- Allow disabling logs, disable logs by default.
- Add bitstream filters by @skeskinen in (:issue:`1375`) (:issue:`1379`).
- Expose CodecContext flush_buffers by @skeskinen in (:issue:`1382`).

Fixes:

- Fix type stubs, add missing type stubs.
- Add S12M_TIMECODE by @WyattBlue in (:issue:`1381`).
- Subtitle.text now returns bytes by @WyattBlue in (:issue:`1398`).
- Allow packet.duration to be writable by @WyattBlue in (:issue:`1399`).
- Remove deprecated `VideoStream.frame_rate` by @WyattBlue in (:issue:`1351`).
- Build with Arm for PyPy now by @WyattBlue in (:issue:`1395`).
- Fix #1378 by @WyattBlue in (:issue:`1400`).
- setup.py: use PKG_CONFIG env var to get the pkg-config to use by @Artturin in (:issue:`1387`).

v12.0.0
-------

Major:

- Add type hints.
- Update FFmpeg to 6.1.1 for the binary wheels.
- Update libraries for the binary wheels (notably dav1d to 1.4.1).
- Deprecate VideoCodecContext.gop_size for decoders by @JoeSchiff in (:issue:`1256`).
- Deprecate frame.index by @JoeSchiff in (:issue:`1218`).

Features:

- Allow using pathlib.Path for av.open by @WyattBlue in (:issue:`1231`).
- Add `max_b_frames` property to CodecContext by @davidplowman in (:issue:`1119`).
- Add `encode_lazy` method to CodecContext by @rawler in (:issue:`1092`).
- Add `color_range` to CodecContext/Frame by @johanjeppsson in (:issue:`686`).
- Set `time_base` for AudioResampler by @daveisfera in (:issue:`1209`).
- Add support for ffmpeg's AVCodecContext::delay by @JoeSchiff in (:issue:`1279`).
- Add `color_primaries`, `color_trc`, `colorspace` to VideoStream by @WyattBlue in (:issue:`1304`).
- Add `bits_per_coded_sample` to VideoCodecContext by @rvanlaar in (:issue:`1203`).
- AssSubtitle.ass now returns as bytes by @WyattBlue in (:issue:`1333`).
- Expose DISPLAYMATRIX side data by @hyenal in (:issue:`1249`).

Fixes:

- Convert deprecated Cython extension class properties to decorator syntax by @JoeSchiff
- Check None packet when setting time_base after decode by @philipnbbc in (:issue:`1281`).
- Remove deprecated `Buffer.to_bytes` by @WyattBlue in (:issue:`1286`).
- Remove deprecated `Packet.decode_one` by @WyattBlue in (:issue:`1301`).

v11.0.0
-------

Major:

- Add support for FFmpeg 6.0, drop support for FFmpeg < 5.0.
- Add support for Python 3.12, drop support for Python < 3.8.
- Build binary wheels against libvpx 1.13.1 to fix CVE-2023-5217.
- Build binary wheels against FFmpeg 6.0.

Features:

- Add support for the `ENCODER_FLUSH` encoder flag (:issue:`1067`).
- Add VideoFrame ndarray operations for yuv444p/yuvj444p formats (:issue:`788`).
- Add setters for `AVFrame.dts`, `AVPacket.is_keyframe` and `AVPacket.is_corrupt` (:issue:`1179`).

Fixes:

- Fix build using Cython 3 (:issue:`1140`).
- Populate new streams with codec parameters (:issue:`1044`).
- Explicitly set `python_requires` to avoid installing on incompatible Python (:issue:`1057`).
- Make `AudioFifo.__repr__` safe before the first frame (:issue:`1130`).
- Guard input container members against use after closes (:issue:`1137`).

v10.0.0
-------

Major:

- Add support for FFmpeg 5.0 and 5.1 (:issue:`817`).
- Drop support for FFmpeg < 4.3.
- Deprecate `CodecContext.time_base` for decoders (:issue:`966`).
- Deprecate `VideoStream.framerate` and `VideoStream.rate` (:issue:`1005`).
- Stop proxying `Codec` from `Stream` instances (:issue:`1037`).

Features:

- Update FFmpeg to 5.1.2 for the binary wheels.
- Provide binary wheels for Python 3.11 (:issue:`1019`).
- Add VideoFrame ndarray operations for gbrp formats (:issue:`986`).
- Add VideoFrame ndarray operations for gbrpf32 formats (:issue:`1028`).
- Add VideoFrame ndarray operations for nv12 format (:issue:`996`).

Fixes:

- Fix conversion to numpy array for multi-byte formats (:issue:`981`).
- Safely iterate over filter pads (:issue:`1000`).

v9.2.0
------

Features:

- Update binary wheels to enable libvpx support.
- Add an `io_open` argument to `av.open` for multi-file custom I/O.
- Add support for AV_FRAME_DATA_SEI_UNREGISTERED (:issue:`723`).
- Ship .pxd files to allow other libraries to `cimport av` (:issue:`716`).

Fixes:

- Fix an `ImportError` when using Python 3.8/3.9 via Conda (:issue:`952`).
- Fix a muxing memory leak which was introduced in v9.1.0 (:issue:`959`).

v9.1.1
------

Fixes:

- Update binary wheels to update dependencies on Windows, disable ALSA on Linux.

v9.1.0
------

Features:

- Add VideoFrame ndarray operations for rgb48be, rgb48le, rgb64be, rgb64le pixel formats.
- Add VideoFrame ndarray operations for gray16be, gray16le pixel formats (:issue:`674`).
- Make it possible to use av.open() on a pipe (:issue:`738`).
- Use the "ASS without timings" format when decoding subtitles.

Fixes:

- Update binary wheels to fix security vulnerabilities (:issue:`921`) and enable ALSA on Linux (:issue:`941`).
- Fix crash when closing an output container an encountering an I/O error (:issue:`613`).
- Fix crash when probing corrupt raw format files (:issue:`590`).
- Fix crash when manipulating streams with an unknown codec (:issue:`689`).
- Remove obsolete KEEP_SIDE_DATA and MP4A_LATM flags which are gone in FFmpeg 5.0.
- Deprecate `to_bytes()` method of Packet, Plane and SideData, use `bytes(packet)` instead.

v9.0.2
------

Minor:

- Update FFmpeg to 4.4.1 for the binary wheels.
- Fix framerate when writing video with FFmpeg 4.4 (:issue:`876`).

v9.0.1
------

Minor:

- Update binary wheels to fix security vulnerabilities (:issue:`901`).

v9.0.0
------

Major:

- Re-implement AudioResampler with aformat and buffersink (:issue:`761`).
  AudioResampler.resample() now returns a list of frames.
- Remove deprecated methods: AudioFrame.to_nd_array, VideoFrame.to_nd_array and Stream.seek.

Minor:

- Provide binary wheels for macOS/arm64 and Linux/aarch64.
- Simplify setup.py, require Cython.
- Update the installation instructions in favor of PyPI.
- Fix VideoFrame.to_image with height & width (:issue:`878`).
- Fix setting Stream time_base (:issue:`784`).
- Replace deprecated av_init_packet with av_packet_alloc (:issue:`872`).
- Validate pixel format in VideoCodecContext.pix_fmt setter (:issue:`815`).
- Fix AudioFrame ndarray conversion endianness (:issue:`833`).
- Improve time_base support with filters (:issue:`765`).
- Allow flushing filters by sending `None` (:issue:`886`).
- Avoid unnecessary vsnprintf() calls in log_callback() (:issue:`877`).
- Make Frame.from_ndarray raise ValueError instead of AssertionError.

v8.1.0
------

Minor:

- Update FFmpeg to 4.3.2 for the binary wheels.
- Provide binary wheels for Python 3.10 (:issue:`820`).
- Stop providing binary wheels for end-of-life Python 3.6.
- Fix args order in Frame.__repr__ (:issue:`749`).
- Fix documentation to remove unavailable QUIET log level (:issue:`719`).
- Expose codec_context.codec_tag (:issue:`741`).
- Add example for encoding with a custom PTS (:issue:`725`).
- Use av_packet_rescale_ts in Packet._rebase_time() (:issue:`737`).
- Do not hardcode errno values in test suite (:issue:`729`).
- Use av_guess_format for output container format (:issue:`691`).
- Fix setting CodecContext.extradata (:issue:`658`, :issue:`740`).
- Fix documentation code block indentation (:issue:`783`).
- Fix link to Conda installation instructions (:issue:`782`).
- Export AudioStream from av.audio (:issue:`775`).
- Fix setting CodecContext.extradata (:issue:`801`).

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
