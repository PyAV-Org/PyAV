Installation
============

Binary wheels
-------------

PyAV requires Python 3.11 or later. Binary wheels are provided on PyPI for Linux, macOS, and Windows with FFmpeg bundled. The most straightforward way to install PyAV is to run:

.. code-block:: bash

    pip install av


Conda
-----

Another way to install PyAV is via `conda-forge <https://conda-forge.github.io>`_::

    conda install av -c conda-forge

See the `Conda quick install <https://docs.conda.io/projects/conda/en/latest/user-guide/install/index.html>`_ docs to get started with Miniconda.


Bring your own FFmpeg
---------------------

PyAV can also be compiled against your own build of FFmpeg 8.x. You can force installing PyAV from source by running:

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


macOS
^^^^^

On **macOS**, install the build dependencies with Homebrew_::

    brew install ffmpeg pkg-config

.. _homebrew: https://brew.sh/


Windows
^^^^^^^

The Windows build uses FFmpeg development files maintained by the PyAV project. From a PowerShell prompt, create a development environment, fetch the libraries into it, and pass their location to the build:

.. code-block:: powershell

    conda create --name pyav-dev --channel conda-forge python=3.11 cython setuptools numpy pillow pytest
    conda activate pyav-dev
    $ffmpegDir = Join-Path $env:CONDA_PREFIX "Library"
    python scripts\fetch-vendor.py --config-file scripts\ffmpeg-latest.json $ffmpegDir
    python setup.py build_ext --inplace --ffmpeg-dir=$ffmpegDir
    python -m pytest

This is the same approach used by PyAV's Windows continuous-integration build.


Building from the latest source on Linux or macOS
-------------------------------------------------

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
