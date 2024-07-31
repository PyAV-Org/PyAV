LDFLAGS ?= ""
CFLAGS ?= "-O0"

PYAV_PYTHON ?= python
PYAV_PIP ?= pip
PYTHON := $(PYAV_PYTHON)
PIP := $(PYAV_PIP)


.PHONY: default build clean fate-suite lint test

default: build


build:
	# Always try to install the Python dependencies they are cheap.
	$(PIP) install --upgrade -r tests/requirements.txt
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
	$(PIP) install --upgrade -r tests/requirements.txt
	black --check av examples tests setup.py
	flake8 av examples tests
	isort --check-only --diff av examples tests
	mypy av tests

test:
	$(PIP) install --upgrade -r tests/requirements.txt
	$(PYTHON) -m pytest
