PyAV
====

PyAV is a Pythonic binding for the [FFmpeg][ffmpeg] libraries. We aim to provide all of the power and control of the underlying library, but manage the gritty details as much as possible.

---

[![GitHub Test Status][github-tests-badge]][github-tests] [![Documentation][docs-badge]][docs] [![Python Package Index][pypi-badge]][pypi] [![Conda Forge][conda-badge]][conda]

PyAV is for direct and precise access to your media via containers, streams, packets, codecs, and frames. It exposes a few transformations of that data, and helps you get your data to/from other packages (e.g. Numpy and Pillow).

This power does come with some responsibility as working with media is horrendously complicated and PyAV can't abstract it away or make all the best decisions for you. If the `ffmpeg` command does the job without you bending over backwards, PyAV is likely going to be more of a hindrance than a help.

But where you can't work without it, PyAV is a critical tool.


Installation
------------

Binary wheels are provided on [PyPI][pypi] for Linux, MacOS and Windows linked against the latest stable version of ffmpeg. You can install these wheels by running:

```bash
pip install av
```

Another way of installing PyAV is via [conda-forge][conda-forge]:

```bash
conda install av -c conda-forge
```

See the [Conda install][conda-install] docs to get started with (mini)Conda.


Alternative installation methods
--------------------------------

Due to the complexity of the dependencies, PyAV is not always the easiest Python package to install from source. If you want to use your existing ffmpeg (must be the correct major version), the source version of PyAV is on [PyPI][pypi]:

> [!WARNING]
> You must be in a posix env, and have the correct version of ffmpeg installed on your system.

```bash
pip install av --no-binary av
```


Installing From Source
----------------------

Here's how to build PyAV from source. You must use [MSYS2](https://www.msys2.org/) when using Windows.

```bash
git clone https://github.com/PyAV-Org/PyAV.git
cd PyAV
source scripts/activate.sh

# Build ffmpeg from source. You can skip this step
# if ffmpeg is already installed.
./scripts/build-deps

# Build PyAV
make

# Testing
make test

# Install globally
deactivate
pip install .
```

---

Have fun, [read the docs][docs], [come chat with us][discuss], and good luck!



[conda-badge]: https://img.shields.io/conda/vn/conda-forge/av.svg?colorB=CCB39A
[conda]: https://anaconda.org/conda-forge/av
[docs-badge]: https://img.shields.io/badge/docs-on%20pyav.basswood--io.com-blue.svg
[docs]: https://pyav.basswood-io.com
[pypi-badge]: https://img.shields.io/pypi/v/av.svg?colorB=CCB39A
[pypi]: https://pypi.org/project/av
[discuss]: https://github.com/PyAV-Org/PyAV/discussions

[github-tests-badge]: https://github.com/PyAV-Org/PyAV/workflows/tests/badge.svg
[github-tests]: https://github.com/PyAV-Org/PyAV/actions?workflow=tests
[github]: https://github.com/PyAV-Org/PyAV

[ffmpeg]: https://ffmpeg.org/
[conda-forge]: https://conda-forge.github.io/
[conda-install]: https://docs.conda.io/projects/conda/en/latest/user-guide/install/index.html
