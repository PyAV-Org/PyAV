Changelog
=========

We are operating with `semantic versioning <https://semver.org>`_.

..
    Update this file in your commit that makes a change (besides maintenance).

    To make merging/rebasing easier, don't manually break lines in here when they are too long.
    To make tracking easier, please add either ``closes #123`` or ``fixes #123`` to the first line of the commit message, when closing/fixing a GitHub issue.
    Changelog entries will be limited to the latest major version and (next) to prevent exponential growth in file storage.
    Use the Oxford comma.

    Entries look like this:

    v21.67.42
    ---------
    Major:

    - Breaking changes (MAJOR) go here, including for binary wheels.

    Features:

    - Features (MINOR) changes go here.

    Fixes:

    - Bug fixes (PATCH) go here. 
    - $CHANGE by :gh-user:`mikeboers` in (:pr:`1`).

v19.0.0 (Unreleased)
--------------------

Major:

- Drop support for Python 3.11. Binary wheels are now built for Python 3.12 and later.
- Remove the undocumented ``CodecContext.hwaccel`` attribute. It held the ``HWAccel`` settings object passed in, not the live device context; use ``CodecContext.is_hwaccel`` to check whether hardware acceleration is in use.
- Rational attributes (``time_base``, ``average_rate``, ``base_rate``, ``guessed_rate``, ``framerate``, ``rate``, ``sample_aspect_ratio``, and ``display_aspect_ratio``) now return :class:`av.AVRational` rather than ``fractions.Fraction``, and are never ``None``: an unset value is the falsy ``AVRational(0, 1)``. Test them with ``if not stream.time_base:`` instead of ``is None``. Setters still accept a ``fractions.Fraction``.
- Closing an :class:`.OutputContainer` now frees its context, so using one afterwards raises ``Container is not open`` instead of continuing against a finished file. Muxing has no ``avformat_close_input()`` to do this for it, so ``add_stream()``, ``mux()``, ``start_encoding()`` and the rest kept working after ``close()``, and streams held from it stayed readable.
- Remove ``Capabilities.hwaccel``, ``Capabilities.hwaccel_vdpau``, and ``Capabilities.neg_linesizes``, none of which FFmpeg defines any more.
- Remove the ``metadata_encoding`` and ``metadata_errors`` arguments to :func:`av.open`, and the matching attributes. Metadata is now always read and written as UTF-8 with ``surrogateescape``, which is byte exact: a tag in another encoding survives as surrogates and is recovered per key with ``value.encode("utf-8", "surrogateescape").decode("cp1251")``. Previously one encoding had to be chosen for a whole container, so a file mixing encodings across tags could not be represented at all.
- Remove the ``stream_options`` argument to :func:`av.open` and the matching attribute. They only ever reached ``avformat_find_stream_info()``, and only for formats that expose their streams before it runs, so they raised for MPEG and friends; output containers rejected them outright. Pass ``options`` for every stream, set ``stream.codec_context.options`` for one, and ``Container.add_stream(..., options={})`` when writing.

Features:

- ``av.dump_codecs()`` now lists every codec FFmpeg knows of rather than only those with an encoder or a decoder, so data and attachment codecs appear, matching ``ffmpeg -codecs``. Its legend gains the ``..D...`` and ``..T...`` media types.
- ``ContainerFormat.fixed_framesize`` reports whether a format wants fixed size audio frames.
- :class:`.CodecContext` exposes more of ``AVCodecContext``: ``pkt_timebase``, ``frame_num``, ``active_thread_type``, ``bits_per_raw_sample``, ``compression_level``, ``rc_buffer_size``, ``min_bit_rate``, a setter for ``max_bit_rate``, the audio ``initial_padding``, ``trailing_padding``, and ``seek_preroll``, and ``stats_in``/``stats_out`` for two-pass encoding. ``VideoCodecContext`` gains ``chroma_sample_location``, ``refs``, and ``mb_decision``; ``AudioCodecContext`` gains ``block_align``.
- ``CodecContext.coded_side_data`` and ``CodecContext.decoded_side_data`` expose the context's global side data as dicts of ``bytes``, keyed by packet side data name and :class:`~av.sidedata.sidedata.Type` respectively. Stream wide HDR metadata, such as mastering display and content light level, arrives in ``decoded_side_data`` once a frame has been decoded.
- ``VideoFrame.chroma_location`` exposes ``AVFrame.chroma_location``, the position of the chroma samples relative to the luma samples, and the new ``ChromaLocation`` enum names its values. Only the codec context side of the field was wrapped, as ``VideoCodecContext.chroma_sample_location``, so the siting a decoder actually reported per frame could not be read at all. Each property mirrors its C field name, which FFmpeg spells differently on the two structs.
- Enums gained the members FFmpeg has since added: ``Properties.FIELDS``, ``Properties.ENHANCEMENT``, ``PixFmtLoss.EXCESS_RESOLUTION``, ``PixFmtLoss.EXCESS_DEPTH``, ``Flags2.icc_profiles``, ``format.Flags.experimental``, ``Interpolation.STRICT``, ``Interpolation.UNSTABLE``, ``ColorTrc.V_LOG``, ``ColorPrimaries.V_GAMUT``, the ``LCEVC``, ``VIEW_ID``, ``THREE_D_REFERENCE_DISPLAYS``, and ``EXIF`` members of ``sidedata.Type``, and the ``exif``, ``dynamic_hdr_smpte_2094_app5``, and ``hevc_conf`` packet side data names.

Fixes:

- ``Frame.side_data`` and ``PacketSideData.data_type`` no longer raise on side data types FFmpeg has added since PyAV last listed them. The packet side data names were missing three, so reading, say, the ``AV_PKT_DATA_HEVC_CONF`` an HEVC stream in MP4 or Matroska carries raised ``IndexError``. A frame side data type that no ``sidedata.Type`` member names, which is anything a newer FFmpeg than PyAV was built against added, now becomes an ``UNKNOWN_<value>`` member rather than raising ``ValueError``.
- ``CodecContext.bit_rate_tolerance`` returns its value instead of always ``None``; the getter was missing its ``return``.
- A rejected ``add_stream()`` or ``add_mux_stream()`` no longer breaks the container.
- ``InputContainer.size`` returns ``None`` when the size cannot be determined rather than the negative ``AVERROR`` it was passing through, which read as a plausible byte count. A non-seekable input, such as a pipe, reported ``-78``.
- ``av.dump_codecs()`` no longer drops the canonical names ``h264``, ``hevc``, ``av1``, ``dirac``, and ``ilbc``, each of which was overwritten by the row of whichever encoder it resolved to.
- ``FilterLink.input`` and ``FilterLink.output`` now follow the filters the graph auto-inserts while configuring. They cached the pad they first resolved, so reading one before ``Graph.configure()`` reported the filter the link no longer pointed at.
- Fix a segfault when a ``FilterLink`` outlives its ``Graph``. It held the graph by weak reference and dereferenced ``AVFilterLink`` before consulting it, so ``link.input`` and ``link.output`` read freed memory. It now holds the graph, as a ``FilterContext`` already did.
- Reading a :class:`.Stream` or its :attr:`~av.stream.Stream.index_entries` after the container is closed now raises instead of reading freed memory, since ``avformat_close_input()`` frees the underlying ``AVStream``. Holding an ``index_entries`` also keeps its container alive, and an :class:`.IndexEntry` is a copy, so it stays readable after the close and is unaffected by the demuxer reallocating the index.
- Attaching one object to the ``opaque`` of more than one frame or packet no longer loses it. The objects were keyed by ``id()``, so every holder shared an entry and whichever was freed first took it away from the rest.
- ``Frame.side_data`` now satisfies the ``Mapping`` protocol it advertises: iteration yields :class:`~av.sidedata.sidedata.Type` keys, so ``items()``, ``keys()``, and ``values()`` work instead of raising ``KeyError``. Values remain reachable positionally by an integer or, for the first time, a slice. Its type stub was a ``TypedDict`` with a single literal key, and is now ``SideDataContainer``.
- Fix crashes from indexes that were turned into C pointer arithmetic without being range checked. ``MotionVectors[i]`` only checked the upper bound, so a negative index read off the front of the buffer (``mvs[-1]`` now returns the last vector, as with any sequence); ``VideoFormatComponent`` and ``AudioPlane`` accepted any index at all; and ``BitmapSubtitlePlane`` and ``VideoBlockParams`` were missing their lower bounds.
- Frames returned by flushing a codec context directly (``CodecContext.decode()`` with no packet) now carry the stream's ``time_base`` instead of ``None``.
- ``VideoFrame.reformat()`` (and so ``to_ndarray(format=...)``, ``to_rgb()``, ``to_image()``) now shares one ``SwsContext`` per thread instead of allocating one per frame. FFmpeg 8's swscale retains megabytes of graph state per context, which showed up as large RSS growth when many frames were alive at once.


18.X and Below
--------------
..
  or see older git commits

`18.X Changelog <https://pyav.basswood.io/docs/18.1/development/changelog.html>`
