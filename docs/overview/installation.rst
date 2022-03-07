Installation
============

Binary wheels
-------------

Since release 8.0.0 binary wheels are provided on PyPI for Linux, Mac and Windows linked against FFmpeg. The most straight-forward way to install PyAV is to run:

.. code-block:: bash

    pip install av


Currently FFmpeg 4.3.3 is used with the following features enabled for all platforms:

- fontconfig
- gmp
- gnutls
- libaom
- libass
- libbluray
- libdav1d
- libfreetype
- libmp3lame
- libopencore-amrnb
- libopencore-amrwb
- libopenjpeg
- libopus
- libspeex
- libtheora
- libtwolame
- libvorbis
- libwavpack
- libx264
- libx265
- libxml2
- libxvid
- lzma
- zlib


Conda
-----

Another way to install PyAV is via `conda-forge <https://conda-forge.github.io>`_::

    conda install av -c conda-forge

See the `Conda quick install <https://conda.io/docs/install/quick.html>`_ docs to get started with (mini)Conda.


Bring your own FFmpeg
---------------------

PyAV can also be compiled against your own build of FFmpeg ((version ``4.0`` or higher). You can force installing PyAV from source by running:

.. code-block:: bash

    pip install av --no-binary av

PyAV depends upon several libraries from FFmpeg:

- ``libavcodec``
- ``libavdevice``
- ``libavfilter``
- ``libavformat``
- ``libavutil``
- ``libswresample``
- ``libswscale``

and a few other tools in general:

- ``pkg-config``
- Python's development headers


Mac OS X
^^^^^^^^

On **Mac OS X**, Homebrew_ saves the day::

    brew install ffmpeg pkg-config

.. _homebrew: http://brew.sh/


Ubuntu >= 18.04 LTS
^^^^^^^^^^^^^^^^^^^

On **Ubuntu 18.04 LTS** everything can come from the default sources::

    # General dependencies
    sudo apt-get install -y python-dev pkg-config

    # Library components
    sudo apt-get install -y \
        libavformat-dev libavcodec-dev libavdevice-dev \
        libavutil-dev libswscale-dev libswresample-dev libavfilter-dev


Windows
^^^^^^^

It is possible to build PyAV on Windows without Conda by installing FFmpeg yourself, e.g. from the `shared and dev packages <https://ffmpeg.zeranoe.com/builds/>`_.

Unpack them somewhere (like ``C:\ffmpeg``), and then :ref:`tell PyAV where they are located <build_on_windows>`.


Building from the latest source
-------------------------------

::

    # Get PyAV from GitHub.
    git clone git@github.com:PyAV-Org/PyAV.git
    cd PyAV

    # Prep a virtualenv.
    source scripts/activate.sh

    # Install basic requirements.
    pip install -r tests/requirements.txt

    # Optionally build FFmpeg.
    ./scripts/build-deps

    # Build PyAV.
    make
    # or
    python setup.py build_ext --inplace


On **Mac OS X** you may have issues with regards to Python expecting gcc but finding clang. Try to export the following before installation::

    export ARCHFLAGS=-Wno-error=unused-command-line-argument-hard-error-in-future


.. _build_on_windows:

On **Windows** you must indicate the location of your FFmpeg, e.g.::

    python setup.py build --ffmpeg-dir=C:\ffmpeg
