Installation
============

Conda
-----

Due to the complexity of the dependencies, PyAV is not always the easiest Python package to install. The most straight-foward install is via `conda-forge <https://conda-forge.github.io>`_::

    conda install av -c conda-forge

See the `Conda quick install <https://conda.io/docs/install/quick.html>`_ docs to get started with (mini)Conda.


Dependencies
------------

PyAV depends upon several libraries from FFmpeg (version ``4.0`` or higher):

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


Ubuntu < 18.04 LTS
^^^^^^^^^^^^^^^^^^

On older Ubuntu releases you will be unable to satisfy these requirements with the default package sources. We recommend compiling and installing FFmpeg from source. For FFmpeg::

    sudo apt install \
        autoconf \
        automake \
        build-essential \
        cmake \
        libass-dev \
        libfreetype6-dev \
        libjpeg-dev \
        libtheora-dev \
        libtool \
        libvorbis-dev \
        libx264-dev \
        pkg-config \
        wget \
        yasm \
        zlib1g-dev

    wget http://ffmpeg.org/releases/ffmpeg-3.2.tar.bz2
    tar -xjf ffmpeg-3.2.tar.bz2
    cd ffmpeg-3.2

    ./configure --disable-static --enable-shared --disable-doc
    make
    sudo make install

`See this script <https://gist.github.com/mkassner/1caa1b45c19521c884d5>`_ for a very detailed installation of all dependencies.


Windows
^^^^^^^

It is possible to build PyAV on Windows without Conda by installing FFmpeg yourself, e.g. from the `shared and dev packages <https://ffmpeg.zeranoe.com/builds/>`_.

Unpack them somewhere (like ``C:\ffmpeg``), and then :ref:`tell PyAV where they are located <build_on_windows>`.



PyAV
----


Via PyPI/CheeseShop
^^^^^^^^^^^^^^^^^^^
::

    pip install av


Via Source
^^^^^^^^^^

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
