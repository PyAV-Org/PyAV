PyAV
====

Pythonic bindings for FFmpeg/Libav.

At least, they will be eventually.... In the future, we hope to represent the majority of these libraries in a Pythonic manner.


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

We are attempting to write this wrapper to work with either FFmpeg_ or Libav_. We are using ctypes_ to detect the differences that we have descerned exist as this wrapper is being developed.

This is a fairly trial-and-error process, so please let ud know if there are any odd compiler errors or something won't link due to missing functions.

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

