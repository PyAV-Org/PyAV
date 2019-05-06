#!/bin/bash

# Make sure this is sourced.
if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
    echo This must be sourced.
    exit 1
fi

export PYAV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"

if [[ "$TRAVIS" ]]; then
    PYAV_LIBRARY=$LIBRARY
fi

if [[ ! "$PYAV_LIBRARY" ]]; then

    # Pull from command line argument.
    if [[ "$1" ]]; then
        PYAV_LIBRARY="$1"
    else
        PYAV_LIBRARY=ffmpeg-4.0
        echo "No \$PYAV_LIBRARY set; defaulting to $PYAV_LIBRARY"
    fi
fi
export PYAV_LIBRARY
_lib_parts=(${PYAV_LIBRARY//-/ })
if [[ ${#_lib_parts[@]} != 2 ]]; then
    echo "Malformed \$PYAV_LIBRARY: \"$PYAV_LIBRARY\""
    exit 1
fi
export PYAV_LIBRARY_NAME=${_lib_parts[0]}
export PYAV_LIBRARY_VERSION=${_lib_parts[1]}


if [[ ! "$PYAV_PYTHON" ]]; then
    PYAV_PYTHON="${PYAV_PYTHON-python3}"
    echo 'No $PYAV_PYTHON set; defaulting to python3.'
fi
export PYAV_PYTHON
export PYAV_PIP="${PYAV_PIP-$PYAV_PYTHON -m pip}"

if [[ "$TRAVIS" ]]; then

    # Travis as a very self-contained environment. Lets just work in that.
    echo "We're on Travis, so not setting up another virtualenv."

    if [[ "$TRAVIS_PYTHON_VERSION" = "2.7" || "$TRAVIS_PYTHON_VERSION" = "pypy2.7-6.0" ]]; then
        PYAV_PYTHON=python
        PYAV_PIP=pip
    fi
else

    export PYAV_VENV_NAME="$(uname -s).$(uname -r).$("$PYAV_PYTHON" -c '
from __future__ import print_function
import sys
import platform
print("{}{}.{}".format(platform.python_implementation().lower(), *sys.version_info[:2]))
    ')"
    export PYAV_VENV="$PYAV_ROOT/venvs/$PYAV_VENV_NAME"

    if [[ ! -e "$PYAV_VENV/bin/python" ]]; then
        mkdir -p "$PYAV_VENV"
        virtualenv -p "$PYAV_PYTHON" "$PYAV_VENV"
        "$PYAV_VENV/bin/pip" install --upgrade pip setuptools
    fi

    if [[ -e "$PYAV_VENV/bin/activate" ]]; then
        source "$PYAV_VENV/bin/activate"
    else
        # Not a virtualenv (perhaps a debug Python); lets manually "activate" it.
        PATH="$PYAV_VENV/bin:$PATH"
    fi

fi


# Just a flag so that we know this was supposedly run.
export _PYAV_ACTIVATED=1

if [[ ! "$PYAV_LIBRARY_BUILD_ROOT" && -d /vagrant ]]; then
    # On Vagrant, building the library in the shared directory causes some
    # problems, so we move it to the user's home.
    PYAV_LIBRARY_ROOT="/home/vagrant/vendor"
fi
export PYAV_LIBRARY_ROOT="${PYAV_LIBRARY_ROOT-$PYAV_ROOT/vendor}"
export PYAV_LIBRARY_BUILD="${PYAV_LIBRARY_BUILD-$PYAV_LIBRARY_ROOT/build}"
export PYAV_LIBRARY_PREFIX="$PYAV_LIBRARY_BUILD/$PYAV_LIBRARY"

export PATH="$PYAV_LIBRARY_PREFIX/bin:$PATH"
export PYTHONPATH="$PYAV_ROOT:$PYTHONPATH"
export PKG_CONFIG_PATH="$PYAV_LIBRARY_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="$PYAV_LIBRARY_PREFIX/lib:$LD_LIBRARY_PATH"
export DYLD_LIBRARY_PATH="$PYAV_LIBRARY_PREFIX/lib:$DYLD_LIBRARY_PATH"
