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

v17.0.2 (next)
--------------

Fixes:


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

`15.X Changelog <https://pyav.basswood-io.com/docs/15.1/development/changelog.html>`
