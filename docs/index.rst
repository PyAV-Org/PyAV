**PyAV** Documentation
======================

**PyAV** is a Pythonic binding for FFmpeg_ or Libav_. We aim to provide all of the power and control of the underlying library, but manage the gritty details as much as possible.

Currently we provide the basics of:

- :class:`containers <.Container>`
- devices (by specifying a format)
- audio/video/subtitle :class:`streams <.Stream>`
- :class:`packets <.Packet>`
- audio/video :class:`frames <.Frame>`
- :class:`data planes <.Plane>`
- :class:`subtitles <.Subtitle>`
- and a few more utilities.

.. _FFmpeg: http://ffmpeg.org
.. _Libav: http://libav.org


Basic Demo
----------

::

    import av

    container = av.open('/path/to/video.mp4')

    for frame in container.decode(video=0):
        frame.to_image().save('/path/to/frame-%04d.jpg' % frame.index)


Contents
--------

.. toctree::
    :maxdepth: 2

    about
    installation
    examples
    api
    hacking
    includes


Indices and Tables
==================
* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`

