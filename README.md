PyAV
====

[![Build Status](https://travis-ci.org/mikeboers/PyAV.svg?branch=develop)](https://travis-ci.org/mikeboers/PyAV) [![Build status](https://ci.appveyor.com/api/projects/status/94w43xhugh6wkett/branch/develop?svg=true)](https://ci.appveyor.com/project/mikeboers/pyav)

PyAV is a Pythonic binding for [FFmpeg][ffmpeg]. We aim to provide all of the power and control of the underlying library, but manage the gritty details as much as possible.


Installation
------------

Due to the complexity of the dependencies, PyAV is not always the easiest Python package to install. The most straight-foward install is via [conda-forge][conda-forge]:

```
conda install av -c conda-forge
```

See the [Conda quick install][conda-install] docs to get started with (mini)Conda.

If you want to use your existing FFmpeg/Libav, the C-source version of PyAV is on [PyPI][pypi]:

```
pip install av
```

And if you want to build from the absolute source (for development or testing):

```
git clone git@github.com:mikeboers/PyAV
cd PyAV
source scripts/activate
make
```

---

Have fun, [Read the Docs][docs], and good luck!


[ffmpeg]: http://ffmpeg.org/
[docs]: http://docs.mikeboers.com/pyav/develop/
[conda-forge]: https://conda-forge.github.io/
[conda-install]: https://conda.io/docs/install/quick.html
[pypi]: https://pypi.org/project/av

