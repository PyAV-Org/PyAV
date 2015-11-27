#!/bin/bash

# Make sure this is sourced.
if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
    echo This must be sourced.
    exit 1
fi

export PYAV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"


PYAV_LIBRARY_NAME="${PYAV_LIBRARY_NAME}"
PYAV_LIBRARY_VERSION="${PYAV_LIBRARY_VERSION}"

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
                PYAV_LIBRARY_VERSION=2.7
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


export PYAV_VENV_NAME="$(uname -s).$(uname -r).cpython$(python -c 'import sys; print "%d.%d" % sys.version_info[:2]')"
export PYAV_VENV="$PYAV_ROOT/venvs/$PYAV_VENV_NAME"

if [[ ! -e "$PYAV_VENV/bin/python" ]]; then
    mkdir -p "$PYAV_VENV"
    virtualenv "$PYAV_VENV"
    "$PYAV_VENV/bin/pip" install --upgrade pip setuptools
fi

source "$PYAV_VENV/bin/activate"


# Just a flag so that we know this was supposedly run.
export _PYAV_ACTIVATED=1



