PyAV
====

[![GitHub Test Status][github-tests-badge]][github-tests] \
[![Gitter Chat][gitter-badge]][gitter] [![Documentation][docs-badge]][docs] \
[![GitHub][github-badge]][github] [![Python Package Index][pypi-badge]][pypi] [![Conda Forge][conda-badge]][conda]

PyAV is a Pythonic binding for the [FFmpeg][ffmpeg] libraries. We aim to provide all of the power and control of the underlying library, but manage the gritty details as much as possible.

PyAV is for direct and precise access to your media via containers, streams, packets, codecs, and frames. It exposes a few transformations of that data, and helps you get your data to/from other packages (e.g. Numpy and Pillow).

This power does come with some responsibility as working with media is horrendously complicated and PyAV can't abstract it away or make all the best decisions for you. If the `ffmpeg` command does the job without you bending over backwards, PyAV is likely going to be more of a hindrance than a help.

But where you can't work without it, PyAV is a critical tool.


Installation
------------

Due to the complexity of the dependencies, PyAV is not always the easiest Python package to install from source. Since release 8.0.0 binary wheels are provided on [PyPI][pypi] for Linux, Mac and Windows linked against a modern FFmpeg. You can install these wheels by running:

```
pip install av
```

If you want to use your existing FFmpeg/Libav, the C-source version of PyAV is on [PyPI][pypi] too:

```
pip install av --no-binary av
```

Alternative installation methods
--------------------------------

Another way of installing PyAV is via [conda-forge][conda-forge]:

```
conda install av -c conda-forge
```

See the [Conda install][conda-install] docs to get started with (mini)Conda.

And if you want to build from the absolute source (for development or testing):

```
git clone git@github.com:PyAV-Org/PyAV
cd PyAV
source scripts/activate.sh

# Either install the testing dependencies:
pip install --upgrade -r tests/requirements.txt
# or have it all, including FFmpeg, built/installed for you:
./scripts/build-deps

# Build PyAV.
make
```

---

Have fun, [read the docs][docs], [come chat with us][gitter], and good luck!



[conda-badge]: https://img.shields.io/conda/vn/conda-forge/av.svg?colorB=CCB39A
[conda]: https://anaconda.org/conda-forge/av
[docs-badge]: https://img.shields.io/badge/docs-on%20pyav.org-blue.svg
[docs]: http://pyav.org/docs
[gitter-badge]: https://img.shields.io/gitter/room/nwjs/nw.js.svg?logo=gitter&colorB=cc2b5e
[gitter]: https://gitter.im/PyAV-Org
[pypi-badge]: https://img.shields.io/pypi/v/av.svg?colorB=CCB39A
[pypi]: https://pypi.org/project/av

[github-tests-badge]: https://github.com/PyAV-Org/PyAV/workflows/tests/badge.svg
[github-tests]: https://github.com/PyAV-Org/PyAV/actions?workflow=tests
[github-badge]: https://img.shields.io/badge/dynamic/xml.svg?label=github&url=https%3A%2F%2Fraw.githubusercontent.com%2FPyAV-Org%2FPyAV%2Fdevelop%2FVERSION.txt&query=.&colorB=CCB39A&prefix=v
[github]: https://github.com/PyAV-Org/PyAV

[ffmpeg]: http://ffmpeg.org/
[conda-forge]: https://conda-forge.github.io/
[conda-install]: https://docs.conda.io/projects/conda/en/latest/user-guide/install/index.html
