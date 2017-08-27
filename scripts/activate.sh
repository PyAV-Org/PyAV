#!/bin/bash

# Make sure this is sourced.
if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
    echo This must be sourced.
    exit 1
fi

export PYAV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"


if [[ ! "$PYAV_LIBRARY_NAME" ]]; then
    # We allow $FFMPEG and $LIBAV on Travis to make the build matrix pretty.
    if [[ "$TRAVIS" && "$FFMPEG" ]]; then
        PYAV_LIBRARY_NAME=ffmpeg
        PYAV_LIBRARY_VERSION="$FFMPEG"
    elif [[ "$TRAVIS" && "$LIBAV" ]]; then
        PYAV_LIBRARY_NAME=libav
        PYAV_LIBRARY_VERSION="$LIBAV"

    # Pull from command line argument.
    elif [[ "$1" ]]; then
        PYAV_LIBRARY_NAME="$1"
    else
        PYAV_LIBRARY_NAME=ffmpeg
        echo "No \$PYAV_LIBRARY_NAME set; defaulting to $PYAV_LIBRARY_NAME"
    fi
fi

if [[ ! "$PYAV_LIBRARY_VERSION" ]]; then

    # Pull from command line argument.
    if [[ "$2" ]]; then
        PYAV_LIBRARY_VERSION="$2"

    # Defaults.
    else
        case "$PYAV_LIBRARY_NAME" in
            ffmpeg)
                PYAV_LIBRARY_VERSION=3.2
                ;;
            libav)
                PYAV_LIBRARY_VERSION=11.4
                ;;
            *)
                echo "Unknown \$PYAV_LIBRARY_NAME \"$PYAV_LIBRARY_NAME\"; exiting"
                exit 1
        esac
        echo "No \$PYAV_LIBRARY_VERSION set; defaulting to $PYAV_LIBRARY_VERSION"
    fi
fi


export PYAV_LIBRARY_NAME
export PYAV_LIBRARY_VERSION
export PYAV_LIBRARY_SLUG=$PYAV_LIBRARY_NAME-$PYAV_LIBRARY_VERSION

export PYAV_PYTHON="${PYAV_PYTHON-python}"
export PYAV_PLATFORM_SLUG="$(uname -s).$(uname -r)"
export PYAV_VENV_NAME="$PYAV_PLATFORM_SLUG.cpython$("$PYAV_PYTHON" -c 'from __future__ import print_function; import sys; print("%d.%d" % sys.version_info[:2])')"
export PYAV_VENV="$PYAV_ROOT/venvs/$PYAV_VENV_NAME"

if [[ ! -e "$PYAV_VENV/bin/python" ]]; then
    mkdir -p "$PYAV_VENV"
    virtualenv "$PYAV_VENV"
    "$PYAV_VENV/bin/pip" install --upgrade pip setuptools
fi

if [[ -e "$PYAV_VENV/bin/activate" ]]; then
    source "$PYAV_VENV/bin/activate"
else
    # Not a virtualenv; lets manually "activate" it.
    PATH="$PYAV_VENV/bin:$PATH"
fi


# Just a flag so that we know this was supposedly run.
export _PYAV_ACTIVATED=1

if [[ ! "$PYAV_LIBRARY_BUILD_ROOT" && -d /vagrant ]]; then
    # On Vagrant, building the library in the shared directory causes some
    # problems, so we move it to the user's home.
    PYAV_LIBRARY_BUILD_ROOT="/home/vagrant/vendor"
fi
export PYAV_LIBRARY_BUILD_ROOT="${PYAV_LIBRARY_BUILD_ROOT-$PYAV_ROOT/vendor}"
export PYAV_LIBRARY_PREFIX="$PYAV_VENV/vendor/$PYAV_LIBRARY_SLUG"

export PATH="$PYAV_LIBRARY_PREFIX/bin:$PATH"
export PYTHONPATH="$PYAV_ROOT:$PYTHONPATH"
export PKG_CONFIG_PATH="$PYAV_LIBRARY_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="$PYAV_LIBRARY_PREFIX/lib:$LD_LIBRARY_PATH"
export DYLD_LIBRARY_PATH="$PYAV_LIBRARY_PREFIX/lib:$DYLD_LIBRARY_PATH"
