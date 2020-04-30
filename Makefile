
PYAV_PYTHON ?= python3
PYTHON := $(PYAV_PYTHON)


.PHONY: build clean clean-all lint test fate-suite docs

default: build


build:
	scripts/build

build-mingw32:
	# before running, set PKG_CONFIG_PATH to the pkgconfig dir of the ffmpeg build.
	# set PKG_CONFIG_PATH=D:\dev\3rd\media-autobuild_suite\local32\bin-video\ffmpegSHARED\lib\pkgconfig
	$(PYTHON) setup.py build_ext --inplace -c mingw32
	mv *.pyd av


fate-suite:
	# Grab ALL of the samples from the ffmpeg site.
	rsync -vrltLW rsync://fate-suite.ffmpeg.org/fate-suite/ tests/assets/fate-suite/

lint:
	scripts/test flake8
	scripts/test isort

test:
	scripts/test


docs: 
	make -C docs


clean-build:
	- rm -rf build
	- find av -name '*.so' -delete

clean-sandbox:
	- rm -rf sandbox/201*
	- rm sandbox/last

clean-src:
	- rm -rf src

clean-docs:
	- rm tmp/Doxyfile
	- rm tmp/tagfile.xml
	- make -C docs clean

clean: clean-build clean-sandbox clean-src
clean-all: clean-build clean-sandbox clean-src clean-docs
