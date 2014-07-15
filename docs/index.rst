**PyAV** Documentation
======================

**PyAV** aims to be a Pythonic binding for FFmpeg_ or Libav_.

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


Installation
------------

From PyPI::

    $ pip install av


From Source::

    $ git clone git@github.com:mikeboers/PyAV.git
    $ cd PyAV
    $ virtualenv venv
    $ . venv/bin/activate
    $ pip install cython pil
    $ make
    $ python setup.py build_ext --inplace


Caveats
-------

We are attempting to write this wrapper to work with either FFmpeg_ or Libav_. We are using ctypes_ to detect the differences that we have discerned exist as this wrapper is being developed. This is a fairly trial-and-error process, so please let us know if there are any odd compiler errors or something won't link due to missing functions.

Additionally, we are far from wrapping the full extents of the libraries. Notable omissions include device and filter support, but there are many C struct members which are currently unexposed.

.. _FFmpeg: http://ffmpeg.org
.. _Libav: http://libav.org
.. _ctypes: http://docs.python.org/2/library/ctypes.html


API Reference
=============

.. toctree::
   :maxdepth: 1

   api


..
	Indices and tables
	==================
	* :ref:`genindex`
	* :ref:`modindex`
	* :ref:`search`


Links
=====

Other important documents include:

- `HACKING.md <https://github.com/mikeboers/PyAV/blob/master/HACKING.md>`_ (developer docs);
- `CHANGELOG.md <https://github.com/mikeboers/PyAV/blob/master/CHANGELOG.md>`_;
- `LICENSE.txt <https://github.com/mikeboers/PyAV/blob/master/LICENSE.txt>`_.
