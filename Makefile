LDFLAGS ?= ""
CFLAGS ?= "-O0"

PYAV_PYTHON ?= python
PYTHON := $(PYAV_PYTHON)


.PHONY: default build clean docs fate-suite lint test

default: build


build:
	CFLAGS=$(CFLAGS) LDFLAGS=$(LDFLAGS) $(PYTHON) setup.py build_ext --inplace --debug

clean:
	- find av -name '*.so' -delete
	- rm -rf build
	- rm -rf sandbox
	- rm -rf src
	- rm -rf tmp
	- make -C docs clean

fate-suite:
	# Grab ALL of the samples from the ffmpeg site.
	rsync -vrltLW rsync://fate-suite.ffmpeg.org/fate-suite/ tests/assets/fate-suite/

lint:
	black --check av examples tests
	flake8 av examples tests
	isort --check-only --diff av examples tests

test:
	$(PYTHON) setup.py test

tmp/ffmpeg-git:
	@ mkdir -p tmp/ffmpeg-git
	git clone --depth=1 git://source.ffmpeg.org/ffmpeg.git tmp/ffmpeg-git

tmp/Doxyfile: tmp/ffmpeg-git
	cp tmp/ffmpeg-git/doc/Doxyfile $@
	echo "GENERATE_TAGFILE = ../tagfile.xml" >> $@

tmp/tagfile.xml: tmp/Doxyfile
	cd tmp/ffmpeg-git; doxygen ../Doxyfile

docs: tmp/tagfile.xml
	PYTHONPATH=.. make -C docs html

deploy-docs: docs
	./docs/upload docs
