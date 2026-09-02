LDFLAGS ?= ""
CFLAGS ?= "-O0 -Wno-unreachable-code"

PYAV_PYTHON ?= python
PYAV_PIP ?= uv pip
PYTHON := $(PYAV_PYTHON)
PIP := $(PYAV_PIP)


.PHONY: default build clean fate-suite lint test pxdpad pxdpad-build

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
	mkdir -p tests/assets/fate-suite/
	rsync -vrltLW rsync://fate-suite.ffmpeg.org/fate-suite/ tests/assets/fate-suite/

lint:
	$(PIP) install --group lint
	ruff format --check av examples tests setup.py
	isort --check-only --diff av examples tests
	mypy av tests

pxdpad-build:
	nim c -d:danger --hints:off -o:tools/pxdpad/bin/pxdpad tools/pxdpad/src/main.nim

pxdpad: pxdpad-build
	tools/pxdpad/bin/pxdpad av include

test:
	$(PIP) install --group test
	$(PYTHON) -m pytest
