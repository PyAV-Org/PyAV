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


Dependencies
------------

PyAV depends upon the following components of the underlying libraries:

- ``libavformat``
- ``libavcodec``
- ``libavdevice``
- ``libavutil``
- ``libswscale``
- ``libswresample`` or ``libavresample``


Mac OS X
^^^^^^^^

On **Mac OS X**, Homebrew_ saves the day::

    brew install ffmpeg


Ubuntu 14.04 LTS
^^^^^^^^^^^^^^^^

On **Ubuntu 14.04 LTS** everything can come from the default sources::

    sudo apt-get install -y \
        libavformat-dev libavcodec-dev libavdevice-dev \
        libavutil-dev libswscale-dev libavresample-dev \


Ubuntu 12.04 LTS
^^^^^^^^^^^^^^^^

On **Ubuntu 12.04 LTS** you will be unable to satisfy these requirements with the default package sources. We recomment compiling and installing FFmpeg or Libav from source. For FFmpeg::

    wget http://ffmpeg.org/releases/ffmpeg-1.2.2.tar.bz2
    tar -xjf ffmpeg-1.2.2.tar.bz2
    cd ffmpeg-1.2.2

    ./configure --disable-static --enable-shared --disable-doc
    make
    sudo make install

`See this script <https://gist.github.com/mkassner/1caa1b45c19521c884d5>`_ for a very detailed installation of all dependencies.



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


On **Mac OS X** you may have issues with regards to Python expecting gcc but finding clang. Try to export the following before installation::
    
    export ARCHFLAGS=-Wno-error=unused-command-line-argument-hard-error-in-future


Windows
^^^^^^^


#. Compile ffmpeg using the mingw64 compiler with shared libraries enabled.

#. Make sure MinGW's GCC compiler is the first gcc found on the path.
   *Important if you have Cygwin on the system as well.*

#. Set the environment variable PKG_CONFIG_PATH to the where the pkgconf files for ffmpeg reside. E.g.::

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

    pip install dist/av-0.2.2-cp27-none-win32.whl

.. note:: Don't try to ``import av`` while in the PyAV source directory, since
    the source directory will get priority, and your build will not get imported.


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
   includes

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



.. _homebrew: http://brew.sh/
