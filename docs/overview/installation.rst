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
