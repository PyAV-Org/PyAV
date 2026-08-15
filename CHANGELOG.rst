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

Fixes:

- Frames returned by flushing a codec context directly (``CodecContext.decode()`` with no packet) now carry the stream's ``time_base`` instead of ``None``.
- ``VideoFrame.reformat()`` (and so ``to_ndarray(format=...)``, ``to_rgb()``, ``to_image()``) now shares one ``SwsContext`` per thread instead of allocating one per frame. FFmpeg 8's swscale retains megabytes of graph state per context, which showed up as large RSS growth when many frames were alive at once.


18.X and Below
--------------
..
  or see older git commits

`18.X Changelog <https://pyav.basswood.io/docs/18.1/development/changelog.html>`
