**PyAV** Documentation
======================

**PyAV** is a Pythonic binding for FFmpeg_ or Libav_. We aim to provide all of the power and control of the underlying library, but manage the gritty details as much as possible.

Currently we provide the basics of:

- ``libavformat``:
  :class:`containers <.Container>`,
  audio/video/subtitle :class:`streams <.Stream>`,
  :class:`packets <.Packet>`;

- ``libavdevice`` (by specifying a format to containers);

- ``libavcodec``:
  :class:`.Codec`,
  :class:`.CodecContext`,
  audio/video :class:`frames <.Frame>`,
  :class:`data planes <.Plane>`,
  :class:`subtitles <.Subtitle>`;

- ``libavfilter``:
  :class:`.Filter`,
  :class:`.Graph`;

- ``libscscale``:
  :class:`.VideoReformatter`;

- ``libavresample`` and/or ``libswresample``:
  :class:`.AudioResampler`;

- and a few more utilities.

.. _FFmpeg: http://ffmpeg.org
.. _Libav: http://libav.org


Basic Demo
----------

.. testsetup::

    path_to_video = common.fate_png() # We don't need a full QT here.


.. testcode::

    import av

    container = av.open(path_to_video)

    for frame in container.decode(video=0):
        frame.to_image().save('frame-%04d.jpg' % frame.index)


Contents
--------

.. toctree::
    :glob:
    :maxdepth: 2

    about
    installation
    examples/_index
    api/_index


.. toctree::
    :maxdepth: 1

    hacking
    includes
    changelog
    contributors
    license


Indices and Tables
==================
* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
