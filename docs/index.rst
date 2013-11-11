PyAV
====

This project aims to be a Pythonic binding for FFmpeg_ or Libav_.

Currently, it includes the basics for reading/writing audio and video. We aim to provide all of the power and control of the underlying library, but manage the gritty details for you as much as possible.


Basic Demo
----------

::

    import av

    container = av.open('/path/to/video.mp4')

    for packet in container.demux():
        for frame in packet.decode():
            if frame.type == 'video':
                frame.to_image().save('/path/to/frame-%04d.jpg' % frame.index)


Installation from PyPI
----------------------

::

    $ pip install av


Building From Source
--------------------

::

    $ git clone git@github.com:mikeboers/PyAV.git
    $ cd PyAV
    $ virtualenv venv
    $ . venv/bin/activate
    $ pip install cython pil
    $ make


FFmpeg vs. Libav
^^^^^^^^^^^^^^^^

We are attempting to write this wrapper to work with either FFmpeg_ or Libav_. We are using ctypes_ to detect the differences that we have discerned exist as this wrapper is being developed.

This is a fairly trial-and-error process, so please let us know if there are any odd compiler errors or something won't link due to missing functions.

.. _FFmpeg: http://ffmpeg.org
.. _Libav: http://libav.org
.. _ctypes: http://docs.python.org/2/library/ctypes.html


API Reference
=============

.. toctree::
   :maxdepth: 2

   api


..
	Indices and tables
	==================
	* :ref:`genindex`
	* :ref:`modindex`
	* :ref:`search`

