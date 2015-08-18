#!/bin/bash

export PYAV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"


PYAV_LIBRARY_NAME="${PYAV_LIBRARY_NAME-$LIBRARY}"
PYAV_LIBRARY_VERSION="${PYAV_LIBRARY_VERSION-$LIBRARY_VERSION}"

if [[ ! "$PYAV_LIBRARY_NAME" ]]; then
    PYAV_LIBRARY_NAME=ffmpeg
    echo "No \$LIBRARY set; defaulting to $PYAV_LIBRARY_NAME"
fi

if [[ ! "$PYAV_LIBRARY_VERSION" ]]; then
    case "$PYAV_LIBRARY_NAME" in
        ffmpeg)
            PYAV_LIBRARY_VERSION=2.7
            ;;
        libav)
            PYAV_LIBRARY_VERSION=11.4
            ;;
        *)
            echo Unknown \$LIBRARY \"$LIBRARY\"; exiting
            exit 1
    esac
    echo "No \$LIBRARY_VERSION set; defaulting to $PYAV_LIBRARY_VERSION"
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


# If this is executed, then execute our args.
if [[ -e "$0" ]]; then
    exec "$@"
fi

