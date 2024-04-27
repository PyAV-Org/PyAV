LDFLAGS ?= ""
CFLAGS ?= "-O0"

PYAV_PYTHON ?= python
PYTHON := $(PYAV_PYTHON)


.PHONY: default build clean fate-suite lint test

default: build


build:
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
	black --check av examples tests setup.py
	flake8 av examples tests
	isort --check-only --diff av examples tests
	mypy av tests

test:
	$(PYTHON) setup.py test
