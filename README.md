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
