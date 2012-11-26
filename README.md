PyAV
====

Pythonic bindinds for libav.

At least, they will be eventually. For now I'm working my way through some ffmpeg/libav tutorials and writing them in Cython.

In the future, I hope to represent the majority of libav in a Pythonic manner.


Hacking
-------

    $ git clone git@github.com:mikeboers/PyAV.git
    $ cd PyAV
    $ virtualenv --system-site-packages venv
    $ . venv/bin/activate
    $ pip install cython pil
    $ make test


FFmpeg Version Info
^^^^^^^^^^^^^^^^^^^

I am developing this with the current (as of this writing) ffmpeg via homebrew:

    ffmpeg version 1.0
    built on Oct  7 2012 15:12:28 with Apple clang version 4.0 (tags/Apple/clang-421.0.57) (based on LLVM 3.1svn)
    configuration: --prefix=/usr/local/Cellar/ffmpeg/1.0 --enable-shared --enable-gpl --enable-version3 --enable-nonfree --enable-hardcoded-tables --cc=cc --host-cflags= --host-ldflags= --enable-libx264 --enable-libfaac --enable-libmp3lame --enable-libxvid
    libavutil      51. 73.101 / 51. 73.101
    libavcodec     54. 59.100 / 54. 59.100
    libavformat    54. 29.104 / 54. 29.104
    libavdevice    54.  2.101 / 54.  2.101
    libavfilter     3. 17.100 /  3. 17.100
    libswscale      2.  1.101 /  2.  1.101
    libswresample   0. 15.100 /  0. 15.100
    libpostproc    52.  0.100 / 52.  0.100

