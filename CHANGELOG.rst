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

v18.1.1 (Unreleased)
--------------------

Fixes:

- Expose ``Frame.best_effort_timestamp``, FFmpeg's estimate of a frame's presentation time, which falls back to the DTS when the PTS is unreliable (:issue:`2477`).
- Fix several crashes from reading freed or out-of-range memory:

  - Reading a :class:`.Stream` or its :attr:`~av.stream.Stream.index_entries` after the container is closed now raises instead of reading freed memory. An :class:`.IndexEntry` is a copy, so it stays readable after the close.
  - Resuming ``demux()`` or ``decode()`` after the container is closed now raises instead of reading the freed format context.
  - ``add_stream_from_template()`` checks that the template's container is still open.
  - Indexes are range checked before being turned into pointer arithmetic: ``MotionVectors[i]`` accepts negative indexes, and ``VideoFormatComponent``, ``AudioPlane``, ``BitmapSubtitlePlane``, and ``VideoBlockParams`` reject out-of-range ones. ``VideoBlockParams`` also keeps its ``VideoEncParams`` alive.
  - A Python file whose ``read(n)`` returns more than ``n`` bytes raises ``ValueError`` instead of overflowing FFmpeg's I/O buffer.
  - ``Packet(bytearray)`` copies the data, so resizing the bytearray afterwards no longer leaves the packet reading freed memory.
  - Inserting into a ``Dictionary`` while iterating it no longer reads an invalidated entry.
  - ``HWConfig`` and the side data wrappers can no longer be left holding a NULL pointer when created through ``__new__``.

- Fix crashes in filter graphs:

  - A ``FilterContext`` or ``FilterLink`` that outlives its ``Graph`` keeps the graph alive instead of using freed memory.
  - ``push()`` to a buffer source configures the graph first, as ``pull()`` does.
  - Filters added or linked after ``Graph.configure()`` are configured on the next push or pull instead of segfaulting.
  - ``FilterContext.link_to`` raises ``ValueError`` when linking filters from different graphs instead of aborting the process.

- ``FilterLink.input`` and ``FilterLink.output`` now follow the filters the graph auto-inserts while configuring, instead of the pad they first resolved.
- ``repr()`` of a filter pad no longer raises ``AttributeError``.
- Fix memory corruption when decoding audio with custom channel layouts (e.g. ``"FR+FL"``), which were shallow-copied and double freed (:issue:`2444`).
- Fix a deadlock when freeing a frame-threaded decoder while a worker thread logs an error. The codec context is now freed with the GIL released (:issue:`2440`).
- Release the GIL around hardware frame transfers.
- Fix corrupted rows in threaded high bit depth ``VideoFrame.reformat()`` on x86 (:issue:`2431`).
- ``VideoFrame.reformat()`` (and so ``to_ndarray(format=...)``, ``to_rgb()``, and ``to_image()``) shares one ``SwsContext`` per thread instead of allocating one per frame, which used megabytes per frame with FFmpeg 8 (:issue:`2320`).
- Fix reference cycles that kept frames, streams, and filters alive until gc ran: reading ``Frame.side_data``, ``MotionVectors`` memoizing its vectors, ``Stream.index_entries`` (:issue:`2425`), and filter pads.
- ``Frame.side_data`` now satisfies the ``Mapping`` protocol it advertises: iteration yields :class:`~av.sidedata.sidedata.Type` keys, so ``items()``, ``keys()``, and ``values()`` work instead of raising ``KeyError``.
- ``Frame.side_data`` and ``PacketSideData.data_type`` no longer raise on side data types FFmpeg has added since PyAV last listed them, such as the ``AV_PKT_DATA_HEVC_CONF`` an HEVC stream in MP4 or Matroska carries.
- Attaching one object to the ``opaque`` of more than one frame or packet no longer loses it when the first holder is freed.
- Frames returned by flushing a codec context directly (``CodecContext.decode()`` with no packet) now carry the stream's ``time_base`` instead of ``None``.
- A failed ``CodecContext.open()`` no longer clears the selected codec, so ``is_encoder`` and ``is_decoder`` keep working and the context can be reopened after fixing the offending parameters.
- A rejected ``add_stream()`` or ``add_mux_stream()`` no longer breaks the container, and a failed stream or output allocation no longer leaks.
- Output containers pass their options to ``avio_open2()``, so protocol options are used by the protocol. By :gh-user:`ANDYwyLEE`.
- ``InputContainer.size`` returns ``None`` when the size cannot be determined instead of a negative error code.
- Audio encoding passes the codec's ``thread_count`` to its internal :class:`.AudioResampler`, which no longer starts an idle thread per CPU for codecs without threading. By :gh-user:`tonyay163`.
- ``AudioFrame.planes`` no longer counts one plane too many for 8-channel planar audio, and no longer reads past ``extended_data`` for more channels. By :gh-user:`ChandraChaan` in (:pr:`2502`).
- ``AudioFifo.write()`` raises ``ValueError`` for a frame whose channel layout differs from the first frame's, instead of scrambling or over-reading the samples. By :gh-user:`ChandraChaan` in (:pr:`2505`).
- ``SubtitleCodecContext.decode(None)`` flushes the decoder instead of raising ``RuntimeError``, so delayed decoders such as EIA-608 closed captions return their final subtitle.
- ``AssSubtitle.dialogue`` strips override tags such as ``{\b1}``, turns ``\n`` and ``\h`` into spaces, treats ``\{`` and ``\}`` as literal braces, and keeps a ``{`` with no closing ``}`` instead of dropping the rest of the line.
- :meth:`.HWAccel.create` passes ``flags`` on to the context it creates instead of dropping them.
- ``Packet(str)`` and setting ``CodecContext.extradata`` to a ``str`` no longer drop the last bytes of non-ASCII text.
- ``AVRational`` values with a zero denominator compare and hash consistently with ``float`` and ``Decimal`` infinities, and its operators return ``NotImplemented`` for unsupported operands.
- ``av.video.frame.supported_np_pix_fmts`` now lists ``yuv422p``.

v18.1.0
-------

Features:

- Infer the specific stream and codec context types for all FFmpeg encoder names in type-checked code by :gh-user:`WyattBlue`.
- Add ``CodecContext.supported_options`` to discover generic and codec-specific options by :gh-user:`WyattBlue` (:issue:`2032`).
- Add ``Packet.rescale_ts()`` to rescale packet PTS, DTS, and duration to a new ``AVRational`` time base by :gh-user:`WyattBlue`.
- Support reusing the thread's current CUDA context via a ``current_ctx`` flag on ``CudaContext`` and ``VideoFrame.from_dlpack``, for interop with libraries like PyTorch that initialize CUDA first by :gh-user:`Yozer` (:pr:`2339`).
- ``VideoFrame.from_dlpack`` no longer requires restating ``primary_ctx``/``current_ctx`` when passing an explicit ``cuda_context``; the flags are only validated when explicitly given by :gh-user:`WyattBlue`.
- Support passing an explicit CUDA stream to FFmpeg CUDA operations, including NVENC input and output, via a ``cuda_stream`` parameter on ``CudaContext``; currently limited to logical CUDA device 0 by :gh-user:`Yozer` (:pr:`2360`).
- Add ``av.AVRational``, an exact rational number stored as two int32s that mirrors FFmpeg's ``AVRational``. ``Codec.frame_rates`` now holds these rather than ``fractions.Fraction``, and every setter that accepts a ``Fraction`` also accepts an ``AVRational``. Unset rational attributes are falsy, so test them with ``if not stream.time_base:`` rather than ``is None`` by :gh-user:`WyattBlue`.
- Add ``Frame.metadata``, the metadata FFmpeg attaches to a frame, by :gh-user:`WyattBlue`.
- Add ``CodecContext.level`` by :gh-user:`WyattBlue`.
- Add ``VideoCodecContext.field_order`` by :gh-user:`WyattBlue`.
- ``VideoFrame.save`` now forwards keyword arguments to the encoder, letting callers trade file size for speed (e.g. ``pred="none"`` or ``compression_level=1`` for PNG, ``qscale=2`` for JPG) by :gh-user:`WyattBlue`.
- Add ``InputContainer.start_time_realtime``, the stream's start time in microseconds since the Unix epoch, which RTSP derives from RTCP sender reports, by :gh-user:`WyattBlue` (:issue:`2365`).

Fixes:

- Fix ``VideoFrame.save`` raising ``AttributeError`` when given a ``Path`` rather than a ``str`` by :gh-user:`WyattBlue`.
- Fix a frame rate assigned to a ``VideoStream`` after ``add_stream`` being dropped from the output; the codec context's frame rate is now copied to the stream before the header is written by :gh-user:`WyattBlue` (:issue:`2301`).

Misc.:

- Support building from source against FFmpeg 9.0 by :gh-user:`WyattBlue`. The binary wheels still ship FFmpeg 8.1.2.

- Prevent crashes and corrupted output when structural codec properties are changed after an output stream has been opened by :gh-user:`WyattBlue`, reported by :gh-user:`oakaigh` (:issue:`2232`).
- Fix a crash when using a stream that has no ``CodecContext`` (a demuxed stream with no available decoder, such as one from a truncated file, or a stream created by ``add_mux_stream``); decoding now raises ``DecoderNotFoundError``, encoding now raises ``EncoderNotFoundError``, and ``BitStreamFilterContext`` accepts such a stream as ``out_stream`` by :gh-user:`WyattBlue`, reported by :gh-user:`justinrmiller` (:issue:`2344`).

v18.0.0
-------

Breaking:

- Remove Python 3.10

Features:

- Support HW encoding via a ``hwaccel`` parameter on ``OutputContainer.add_stream`` (e.g. ``h264_vaapi``, ``h264_nvenc``, ``h264_videotoolbox``); software frames passed to ``encode`` are uploaded to the device automatically by :gh-user:`WyattBlue` (:issue:`2156`).
- Use FFmpeg 8.1.2 in the binary wheels by :gh-user:`WyattBlue`.
- Expose ``sw_format`` on ``VideoCodecContext``, and allow configuring the software format of hardware encoders by :gh-user:`WyattBlue`.
- Add ``options`` parameter to ``AudioResampler`` for passing ``libswresample`` options (e.g. ``resampler``, ``filter_size``, ``cutoff``) by :gh-user:`WyattBlue` (:issue:`2262`).
- Support ``yuv420p10le`` in ``VideoFrame.to_ndarray`` and ``VideoFrame.from_ndarray`` by :gh-user:`WyattBlue` (:issue:`1981`).
- Add ``at`` parameter to ``Graph.push`` and ``Graph.vpush`` to push a frame to a single buffer source by index, for multi-input filters like ``overlay`` by :gh-user:`WyattBlue`.
- ``find_best_pix_fmt_of_list`` now returns the loss as a ``PixFmtLoss`` ``enum.IntFlag`` instead of a plain ``int`` by :gh-user:`WyattBlue` (:issue:`2300`).
- Add ``Colorspace.BT2020`` by :gh-user:`mark-oshea`.
- ``BitStreamFilterContext`` now accepts a ``Codec`` or a codec-name ``str`` as ``in_stream`` to pin the input codec without a full ``Stream`` by :gh-user:`WyattBlue`.

Fixes:

- Fix ``VideoFrame.reformat`` (and ``to_ndarray``/``to_rgb``/``to_image``) raising ``OSError`` ``Operation not supported`` on frames tagged with reserved or otherwise unsupported ``color_primaries``/``color_trc`` values (e.g. VP9 and NVDEC output); a transfer/primaries conversion is now only performed when explicitly requested by :gh-user:`WyattBlue` (:issue:`2208`).
- Fix ``add_mux_stream`` producing unwritable Matroska files by extracting codec extradata from the bitstream before the header is written by :gh-user:`WyattBlue` (:issue:`2198`).
- Encode GPU frames (e.g. CUDA frames from DLPack) directly with ``pix_fmt="cuda"`` by adopting the frame's ``hw_frames_ctx`` before opening the encoder by :gh-user:`WyattBlue` (:issue:`2199`).
- Fix a crash when reading ``VideoCodecContext.pix_fmt`` before it is set; it now returns ``None`` by :gh-user:`CarlosRDomin`.
- Preserve frame attributes (``pts``, ``time_base``, colorspace, etc.) when downloading hardware frames to system memory by :gh-user:`CarlosRDomin`.

v17.1.0
-------

Breaking:

- Remove the undertested ``av.option`` and ``av.descriptor`` APIs, along with the related ``Codec`` and ``Filter`` descriptor accessors.

Features:

- Use FFmpeg 8.1.1 in the binary wheels by :gh-user:`WyattBlue`.
- Build Linux ARMv7 binary wheels by :gh-user:`WyattBlue`.
- Expose ``AVCodecContext.global_quality`` by :gh-user:`WyattBlue` in (:pr:`2246`).
- Expose ``Stream.discard`` so demuxing and seeking can skip unwanted streams by :gh-user:`WyattBlue` (:issue:`2272`).
- Add ``Stream.set_display_matrix()`` and ``Stream.set_display_rotation()`` to write the container display (rotation) matrix on output streams by :gh-user:`hmaarrfk` in (:pr:`2287`).
- Add ``Container.video_codec_id`` to force a specific video codec on a container by :gh-user:`WyattBlue` (:issue:`2243`).

Fixes:

- Add ``cython.final`` to leaf classes, ensuring that they are not subclassed by :gh-user:`WyattBlue`.
- Warn that ``CodecContext.decode()`` is not memory safe in some cases.
- Fix memory leaks in ``FFmpegError``, ``AudioLayout`` channel layouts, and ``Frame.opaque``, and break a reference cycle between ``FilterLink`` and ``Graph`` by :gh-user:`lgeiger`.
- Reduce excessive logging lock contention by :gh-user:`WyattBlue` (:issue:`2276`).
- Fix a crash when accessing ``Stream`` from multiple threads under FFmpeg 8.1 by :gh-user:`WyattBlue` (:issue:`2247`).
- Fix a crash during ``InputContainer`` initialization by :gh-user:`WyattBlue` (:issue:`2010`).
- Fix ``enumerate_input_devices`` and ``enumerate_output_devices`` raising ``AttributeError`` by :gh-user:`WyattBlue` and :gh-user:`kazuki` (:issue:`2264`).
- Map HTTP 429 to ``HTTPTooManyRequestsError`` instead of ``UndefinedError`` by :gh-user:`WyattBlue` (:issue:`2267`).
- Fix crash in ``VideoFrame.to_ndarray()`` and ``to_image()`` on bottom-up frames with a negative ``line_size`` by :gh-user:`WyattBlue` (:issue:`2213`).
- Make ``Disposition`` an ``IntFlag`` so ``Stream.disposition`` can be assigned without raising ``TypeError`` by :gh-user:`HotariTobu`.
- Assign parser-inferred ``pts``, ``dts``, and ``duration`` to packets from ``CodecContext.parse()`` by :gh-user:`WyattBlue` (:issue:`1919`).
- Copy ``time_base`` in ``add_stream_from_template()`` by :gh-user:`daveisfera` in (:pr:`2249`).
- Fix the remux examples dropping keyframes that demux with no DTS, which produced audio-only output by :gh-user:`WyattBlue` (:issue:`1917`).
- Fix subtitle UTF-8 handling by :gh-user:`jbree` in (:pr:`2271`).
- Fix several incorrect ``malloc`` size calculations by :gh-user:`WyattBlue`.

v17.0.1
-------

Fixes:

- A cdivision decorator for faster division.
- Adjust tests so they work with 8.1 by :gh-user:`strophy`.
- Make VideoFormat.components lazy by :gh-user:`WyattBlue`.
- Break reference cycle ``StreamContainer.get()`` by :gh-user:`lgeiger`.
- Expose threads in filter graph by :gh-user:`lgeiger`.
- Fix crash with container closing with GC by :gh-user:`WyattBlue`.
- Fix "Writing packets to data stream broken in av>=17" regression :issue:`2223` by :gh-user:`WyattBlue`.
- Remove ``_send_packet_and_recv`` to simplify ``decode()`` by :gh-user:`lgeiger`.
- Reuse a ``AVPacket`` read buffer when demuxing by :gh-user:`lgeiger` and :gh-user:`WyattBlue`.
- Use ``AVCodecContext.frame_num`` instead of counting ourselves by :gh-user:`WyattBlue`.
- Use ``av_channel_layout_compare()`` for ``AudioLayout.__eq__()`` by :gh-user:`WyattBlue`.

v17.0.0
-------

Major:

- Limited API binary wheels are now built.
- 3.13t (free-threading) will be dropped because of storage limitations.
- When an FFmpeg C function indicates an error, raise av.ArgumentError instead of ValueError/av.ValueError. This helps disambiguate why an exception is being thrown.
- Save space by removing libaom (av1 encoder/decoder); dav1d, stvav1, and hardware, are available alternatives.

Features:

- Add ``OutputContainer.add_mux_stream()`` for creating codec-context-free streams, enabling muxing of pre-encoded packets without an encoder, addressing :issue:`1970` by :gh-user:`WyattBlue`.
- Use zero-copy for Packet init from buffer data by :gh-user:`WyattBlue` in (:pr:`2199`).
- Expose AVIndexEntry by :gh-user:`Queuecumber` in (:pr:`2136`).
- Preserving hardware memory during cuvid decoding, exporting/importing via dlpack by :gh-user:`WyattBlue` in (:pr:`2155`).
- Add enumerate_input_devices and enumerate_output_devices API by :gh-user:`WyattBlue` in (:pr:`2174`).
- Add ``ColorTrc`` and ``ColorPrimaries`` enums; add ``color_trc`` and ``color_primaries`` properties to ``VideoFrame``; add ``dst_color_trc`` and ``dst_color_primaries`` parameters to ``VideoFrame.reformat()``, addressing :issue:`1968` by :gh-user:`WyattBlue` in (:pr:`2175`).
- Add multithreaded reformatting and reduce Python overhead by replacing ``sws_scale`` with ``sws_scale_frame``, skipping unnecessary reformats, and minimizing Python interactions by :gh-user:`lgeiger`.
- Prevent data copy in ``VideoFrame.to_ndarray()`` for padded frames by :gh-user:`lgeiger` in (:pr:`2190`).

Fixes:

- Fix :issue:`2149` by :gh-user:`WyattBlue` in (:pr:`2155`).
- Fix packet typing based on stream and specify InputContainer.demux based on incoming stream by :gh-user:`ntjohnson1` in (:pr:`2134`).
- Fix memory growth when remuxing with ``add_stream_from_template`` by skipping ``avcodec_open2`` for template-initialized codec contexts, addressing :issue:`2135` by :gh-user:`WyattBlue`.
- Explicitly disable OpenSSL in source builds (``scripts/build-deps``) to prevent accidental OpenSSL linkage that breaks FIPS-enabled systems, addressing :issue:`1972`.
- Add missing ``SWS_SPLINE`` interpolation by :gh-user:`lgeiger` in (:pr:`2188`).

v16.1.0
-------

Features:

- Add support for Intel QSV codecs by :gh-user:`ladaapp`.
- Add AMD AMF hardware decoding by :gh-user:`ladaapp2`.
- Add subtitle encoding support by :gh-user:`skeskinen` in (:pr:`2050`).
- Add read/write access to PacketSideData by :gh-user:`skeskinen` in (:pr:`2051`).
- Add yuv422p support for video frame to_ndarray and from_ndarray by :gh-user:`wader` in (:pr:`2054`).
- Add binding for ``avcodec_find_best_pix_fmt_of_list()`` by :gh-user:`ndeybach` in (:pr:`2058`).

Fixes:

- Fix #2036, #2053, #2057 by :gh-user:`WyattBlue`.

v16.0.1
-------

Fixes:

- Add new hwaccel enums by :gh-user:`WyattBlue` in (:pr:`2030`).

v16.0.0
-------

Major:

- Drop Python 3.9, Support Python 3.14.
- Drop support for i686 Linux.

Features:

- Add ``Filter.Context.process_command()`` method by :gh-user:`caffeinism` in (:pr:`2000`).
- Add packet side-data handling mechanism by :gh-user:`tikuma-lsuhsc` in (:pr:`2003`).
- Implemented set_chapters method by :gh-user:`DE-AI` in (:pr:`2004`).
- Declare free-threaded support and support 3.13t by :gh-user:`ngoldbaum` in (:pr:`2005`).
- Add writable and copyable attachment and data streams by :gh-user:`skeskinen` in (:pr:`2026`).

Fixes:

- Declare free-threaded support and support 3.13t by :gh-user:`ngoldbaum` in (:pr:`2005`).
- Allow ``None`` in ``FilterContext.push()`` type stub by :gh-user:`velsinki` in (:pr:`2015`).
- Fix typos

15.X and Below
--------------
..
  or see older git commits

`15.X Changelog <https://pyav.basswood.io/docs/15.1/development/changelog.html>`
