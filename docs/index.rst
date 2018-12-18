**PyAV** Documentation
======================

**PyAV** is a Pythonic binding for FFmpeg_. We aim to provide all of the power and control of the underlying library, but manage the gritty details as much as possible.

PyAV is for direct and precise access to your media via containers, streams, packets, codecs, and frames. It exposes a few transformations of that data, and helps you get your data to/from other packages (e.g. Numpy and Pillow). 

This power does come with some responsibility as working with media is horrendously complicated and PyAV can't abstract it away or make all the best decisions for you. If the `ffmpeg` command does the job without you bending over backwards, PyAV is likely going to be more of a hindrance than a help.

But where you can't work without it, PyAV is a critical tool.

Currently we provide:

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

- ``libswscale``:
  :class:`.VideoReformatter`;

- ``libswresample``:
  :class:`.AudioResampler`;

- and a few more utilities.

.. _FFmpeg: http://ffmpeg.org


Basic Demo
----------

.. testsetup::

    path_to_video = common.fate_png() # We don't need a full QT here.


.. testcode::

    import av

    container = av.open(path_to_video)

    for frame in container.decode(video=0):
        frame.to_image().save('frame-%04d.jpg' % frame.index)


Overview
--------

.. toctree::
    :maxdepth: 2

    about
    installation


Cookbook
--------

.. toctree::
    :glob:
    :maxdepth: 2

    cookbook/*


Reference
---------

.. toctree::
    :glob:
    :maxdepth: 2

    api/*


Development
-----------

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
