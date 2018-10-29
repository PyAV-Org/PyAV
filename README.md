PyAV
====

[![Travis Build Status][travis-badge]][travis] [![AppVeyor Build Status][appveyor-badge]][appveyor] \
[![Gitter Chat][gitter-badge]][gitter] [![Documentation][docs-badge]][docs] \
[![GitHub][github-badge]][github] [![Python Package Index][pypi-badge]][pypi] [![Conda Forge][conda-badge]][conda]

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

Have fun, [read the docs][docs], [come chat with us][gitter], and good luck!



[appveyor-badge]: https://img.shields.io/appveyor/ci/mikeboers/PyAV/develop.svg?logo=appveyor&label=appveyor
[appveyor]: https://ci.appveyor.com/project/mikeboers/pyav
[conda-badge]: https://img.shields.io/conda/vn/conda-forge/av.svg?colorB=CCB39A
[conda]: https://anaconda.org/conda-forge/av
[docs-badge]: https://img.shields.io/badge/docs-on%20mikeboers.com-blue.svg
[docs]: http://docs.mikeboers.com/pyav/develop/
[gitter-badge]: https://img.shields.io/gitter/room/nwjs/nw.js.svg?logo=gitter&colorB=cc2b5e
[gitter]: https://gitter.im/mikeboers/PyAV
[pypi-badge]: https://img.shields.io/pypi/v/av.svg?colorB=CCB39A
[pypi]: https://pypi.org/project/av
[travis-badge]: https://img.shields.io/travis/mikeboers/PyAV/develop.svg?logo=travis&label=travis
[travis]: https://travis-ci.org/mikeboers/PyAV

[github-badge]: https://img.shields.io/badge/dynamic/xml.svg?label=github&url=https%3A%2F%2Fraw.githubusercontent.com%2Fmikeboers%2FPyAV%2Fdevelop%2FVERSION.txt&query=.&colorB=CCB39A&prefix=v
[github]: https://github.com/mikeboers/PyAV

[ffmpeg]: http://ffmpeg.org/
[conda-forge]: https://conda-forge.github.io/
[conda-install]: https://conda.io/docs/install/quick.html

