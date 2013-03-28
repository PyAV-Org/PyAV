PyAV
====

Pythonic bindings for FFmpeg/Libav.

At least, they will be eventually. For now I'm working my way through some tutorials and writing them in Cython.

In the future, I hope to represent the majority of these libraries in a Pythonic manner.


Building From Source
--------------------

::

    $ git clone git@github.com:mikeboers/PyAV.git
    $ cd PyAV
    $ virtualenv venv
    $ . venv/bin/activate
    $ pip install cython pil
    $ make test


FFmpeg vs. Libav
^^^^^^^^^^^^^^^^

I am attempting to write this wrapper to work with either FFmpeg_ or Libav_. I am using autoconf to detect the differences that I have descerned exist as this wrapper is being developed.

This is a fairly trial-and-error process, so please let me know if there are any odd compiler errors or something won't link due to missing functions.

.. _FFmpeg: http://ffmpeg.org/
.. _Libav: http://libav.org/


API Reference
=============

.. toctree::
   :maxdepth: 2

   api/format
   api/codec


..
	Indices and tables
	==================
	* :ref:`genindex`
	* :ref:`modindex`
	* :ref:`search`

