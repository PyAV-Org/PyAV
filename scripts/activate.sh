#!/bin/bash


# Make sure this is sourced.
if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
    echo This must be sourced.
    exit 1
fi

# Locate the PyAV root (relative to this file).
export PYAV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"


# Identify which FFmpeg we're building against.
if [[ ! "$PYAV_LIBRARY" ]]; then
    if [[ "$1" ]]; then
        # Pull from command line argument.
        PYAV_LIBRARY="$1"
    else
        PYAV_LIBRARY=ffmpeg-4.2
        echo "No \$PYAV_LIBRARY set; defaulting to $PYAV_LIBRARY"
    fi
fi
export PYAV_LIBRARY


# Identify which Python we're using.
if [[ ! "$PYAV_PYTHON" ]]; then
    PYAV_PYTHON="${PYAV_PYTHON-python3}"
    echo "No \$PYAV_PYTHON set; defaulting to $PYAV_PYTHON"
fi
# Hack for PyPy on GitHub Actions.
# This is because PYAV_PYTHON is constructed from "python${{ matrix.config.python }}"
# resulting in "pythonpypy3", which won't work.
# It would be nice to clean this up, but I want it to work ASAP.
if [[ "$PYAV_PYTHON" == *pypy* ]]; then
    PYAV_PYTHON=python
fi
export PYAV_PYTHON

export PYAV_PIP="${PYAV_PIP-$PYAV_PYTHON -m pip}"


# Setup a virtualenv, but only if local.
if [[ ! "$GITHUB_ACTION" ]]; then

    # Have a venv for every OS/Python version.
    export PYAV_VENV_NAME="$(uname -s).$(uname -r).$("$PYAV_PYTHON" -c '
import sys
import platform
print("{}{}.{}".format(platform.python_implementation().lower(), *sys.version_info[:2]))
    ')"
    export PYAV_VENV="$PYAV_ROOT/venvs/$PYAV_VENV_NAME"

    # Make the virtualenv if it doesn't exist.
    if [[ ! -e "$PYAV_VENV/bin/activate" ]]; then
        echo "Creating virtualenv $PYAV_VENV"
        mkdir -p "$PYAV_VENV"
        "$PYAV_PYTHON" -m venv "$PYAV_VENV"
        "$PYAV_VENV/bin/pip" install --upgrade pip setuptools
    fi

    source "$PYAV_VENV/bin/activate"

fi



# Identify where our FFmpeg is (that we build/use for development and testing).
export PYAV_LIBRARY_ROOT="${PYAV_LIBRARY_ROOT-$PYAV_ROOT/vendor}"
export PYAV_LIBRARY_BUILD="${PYAV_LIBRARY_BUILD-$PYAV_LIBRARY_ROOT/build}"
export PYAV_LIBRARY_PREFIX="$PYAV_LIBRARY_BUILD/$PYAV_LIBRARY"


# Add our FFmpeg to the environment.
export PATH="$PYAV_LIBRARY_PREFIX/bin:$PATH"
export PYTHONPATH="$PYAV_ROOT:$PYTHONPATH"
export PKG_CONFIG_PATH="$PYAV_LIBRARY_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="$PYAV_LIBRARY_PREFIX/lib:$LD_LIBRARY_PATH"
export DYLD_LIBRARY_PATH="$PYAV_LIBRARY_PREFIX/lib:$DYLD_LIBRARY_PATH"


# Flag that this was run.
export PYAV_ACTIVATED=1

