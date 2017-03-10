Installation
============

Conda
-----

Due to the complexity of the dependencies, PyAV is not always the easiest Python package to install. The most straight-foward install is via `conda-forge <https://conda-forge.github.io>`_::

    conda install av -c conda-forge

See the `Conda quick install <https://conda.io/docs/install/quick.html>`_ docs to get started with (mini)Conda.


Dependencies
------------

PyAV depends upon the following components of the underlying libraries:

- ``libavformat``
- ``libavcodec``
- ``libavdevice``
- ``libavutil``
- ``libswscale``
- ``libswresample`` or ``libavresample``

and a few other tools in general:

- ``pkg-config``
- Python's development headers


Mac OS X
^^^^^^^^

On **Mac OS X**, Homebrew_ saves the day::

    brew install ffmpeg pkg-config

.. _homebrew: http://brew.sh/


Ubuntu 14.04 LTS
^^^^^^^^^^^^^^^^

On **Ubuntu 14.04 LTS** everything can come from the default sources::

    # General dependencies
    sudo apt-get install -y python-dev pkg-config

    # Library components
    sudo apt-get install -y \
        libavformat-dev libavcodec-dev libavdevice-dev \
        libavutil-dev libswscale-dev libavresample-dev


Ubuntu 12.04 LTS
^^^^^^^^^^^^^^^^

On **Ubuntu 12.04 LTS** you will be unable to satisfy these requirements with the default package sources. We recommend compiling and installing FFmpeg or Libav from source. For FFmpeg::

    wget http://ffmpeg.org/releases/ffmpeg-2.7.tar.bz2
    tar -xjf ffmpeg-2.7.tar.bz2
    cd ffmpeg-2.7

    ./configure --disable-static --enable-shared --disable-doc
    make
    sudo make install

`See this script <https://gist.github.com/mkassner/1caa1b45c19521c884d5>`_ for a very detailed installation of all dependencies.



PyAV
----


Via PyPI/CheeseShop
^^^^^^^^^^^^^^^^^^^
::

    $ pip install av


Via Source
^^^^^^^^^^
::

    $ git clone git@github.com:mikeboers/PyAV.git
    $ cd PyAV
    $ virtualenv venv
    $ . venv/bin/activate
    $ pip install cython
    $ python setup.py build_ext --inplace


On **Mac OS X** you may have issues with regards to Python expecting gcc but finding clang. Try to export the following before installation::
    
    export ARCHFLAGS=-Wno-error=unused-command-line-argument-hard-error-in-future


On Windows
^^^^^^^^^^

#. Compile FFmpeg using the mingw64 compiler with shared libraries enabled.

#. Make sure MinGW's GCC compiler is the first gcc found on the path.
   *Important if you have Cygwin on the system as well.*

#. Set ``%PKG_CONFIG_PATH%`` to the location of FFmpeg's ``pkg-config`` files, e.g.::

    set PKG_CONFIG_PATH=c:\ffmpeg_build\lib\pkgconfig

#. Copy the following ffmpeg libraries to the project's av folder:

    - avcodec-56.dll
    - avdevice-56.dll
    - avfilter-5.dll
    - avformat-56.dll
    - avutil-54.dll
    - postproc-53.dll
    - swresample-1.dll
    - swscale-3.dll

   Also copy the two dependent DLLs from mingw to the same folder:

    - libgcc_s_dw2-1.dll
    - libwinpthread-1.dll

#. Build the project::

    make build-mingw32

#. Create a self contained wheel archive that you can install on any machine::

    make wheel

#. Install the package::

    pip install dist/av-0.2.3-cp27-none-win32.whl


