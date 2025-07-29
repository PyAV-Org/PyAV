Installation
============

Binary wheels
-------------

Binary wheels are provided on PyPI for Linux, MacOS, and Windows linked against FFmpeg. The most straight-forward way to install PyAV is to run:

.. code-block:: bash

    pip install av


Conda
-----

Another way to install PyAV is via `conda-forge <https://conda-forge.github.io>`_::

    conda install av -c conda-forge

See the `Conda quick install <https://docs.conda.io/projects/conda/en/latest/user-guide/install/index.html>`_ docs to get started with (mini)Conda.


Bring your own FFmpeg
---------------------

PyAV can also be compiled against your own build of FFmpeg (version ``7.0`` or higher). You can force installing PyAV from source by running:

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


MacOS
^^^^^

On **MacOS**, Homebrew_ saves the day::

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
    git clone https://github.com/PyAV-Org/PyAV.git
    cd PyAV

    # Prep a virtualenv.
    source scripts/activate.sh

    # Optionally build FFmpeg.
    ./scripts/build-deps

    # Build PyAV.
    make

On **MacOS** you may have issues with regards to Python expecting gcc but finding clang. Try to export the following before installation::

    export ARCHFLAGS=-Wno-error=unused-command-line-argument-hard-error-in-future


.. _build_on_windows:

On **Windows** you must indicate the location of your FFmpeg, e.g.::

    python setup.py build --ffmpeg-dir=C:\ffmpeg
