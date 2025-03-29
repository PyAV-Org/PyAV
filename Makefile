LDFLAGS ?= ""
CFLAGS ?= "-O0 -Wno-incompatible-pointer-types -Wno-unreachable-code"

PYAV_PYTHON ?= python
PYAV_PIP ?= pip
PYTHON := $(PYAV_PYTHON)
PIP := $(PYAV_PIP)


.PHONY: default build clean fate-suite lint test

default: build


build:
	$(PIP) install -U --pre cython setuptools
	CFLAGS=$(CFLAGS) LDFLAGS=$(LDFLAGS) $(PYTHON) setup.py build_ext --inplace --debug

clean:
	- find av -name '*.so' -delete
	- rm -rf build
	- rm -rf sandbox
	- rm -rf src
	- make -C docs clean

fate-suite:
	# Grab ALL of the samples from the ffmpeg site.
	rsync -vrltLW rsync://fate-suite.ffmpeg.org/fate-suite/ tests/assets/fate-suite/

lint:
	$(PIP) install -U black isort flake8 flake8-pyproject pillow numpy mypy==1.15.0 pytest
	black --check av examples tests setup.py
	flake8 av
	isort --check-only --diff av examples tests
	mypy av tests

test:
	$(PIP) install --upgrade cython numpy pillow pytest
	$(PYTHON) -m pytest
