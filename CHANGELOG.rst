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
- Remove ``Capabilities.hwaccel``, ``Capabilities.hwaccel_vdpau``, and ``Capabilities.neg_linesizes``, none of which FFmpeg defines any more.

Features:

- ``av.dump_codecs()`` now lists every codec FFmpeg knows of rather than only those with an encoder or a decoder, so data and attachment codecs appear, matching ``ffmpeg -codecs``. Its legend gains the ``..D...`` and ``..T...`` media types.
- ``ContainerFormat.fixed_framesize`` reports whether a format wants fixed size audio frames.
- Enums gained the members FFmpeg has since added: ``Properties.FIELDS``, ``Properties.ENHANCEMENT``, ``PixFmtLoss.EXCESS_RESOLUTION``, ``PixFmtLoss.EXCESS_DEPTH``, ``Flags2.icc_profiles``, ``format.Flags.experimental``, ``Interpolation.STRICT``, ``Interpolation.UNSTABLE``, ``ColorTrc.V_LOG``, ``ColorPrimaries.V_GAMUT``, and the ``LCEVC``, ``VIEW_ID``, ``THREE_D_REFERENCE_DISPLAYS``, and ``EXIF`` members of ``sidedata.Type``.

Fixes:

- ``av.dump_codecs()`` no longer drops the canonical names ``h264``, ``hevc``, ``av1``, ``dirac``, and ``ilbc``, each of which was overwritten by the row of whichever encoder it resolved to.
- Fix crashes from indexes that were turned into C pointer arithmetic without being range checked. ``MotionVectors[i]`` only checked the upper bound, so a negative index read off the front of the buffer (``mvs[-1]`` now returns the last vector, as with any sequence); ``VideoFormatComponent`` and ``AudioPlane`` accepted any index at all; and ``BitmapSubtitlePlane`` and ``VideoBlockParams`` were missing their lower bounds.
- Frames returned by flushing a codec context directly (``CodecContext.decode()`` with no packet) now carry the stream's ``time_base`` instead of ``None``.
- ``VideoFrame.reformat()`` (and so ``to_ndarray(format=...)``, ``to_rgb()``, ``to_image()``) now shares one ``SwsContext`` per thread instead of allocating one per frame. FFmpeg 8's swscale retains megabytes of graph state per context, which showed up as large RSS growth when many frames were alive at once.


18.X and Below
--------------
..
  or see older git commits

`18.X Changelog <https://pyav.basswood.io/docs/18.1/development/changelog.html>`
