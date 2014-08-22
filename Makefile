CYTHON_SRC = $(shell find av -name "*.pyx")
C_SRC = $(CYTHON_SRC:%.pyx=src/%.c)
MOD_SOS = $(CYTHON_SRC:%.pyx=%.so)

TEST_MOV = sandbox/640x360.mp4

LDFLAGS ?= ""
CFLAGS ?= "-O0"

.PHONY: default build cythonize clean clean-all info test docs

default: cythonize

info:
	@ echo Cython sources: $(CYTHON_SRC)

cythonize: $(C_SRC)

src/%.c: %.pyx
	@ mkdir -p $(shell dirname $@)
	cython -I. -Iinclude -o $@ $<

build: cythonize
	CFLAGS=$(CFLAGS) LDFLAGS=$(LDFLAGS) python setup.py build_ext --inplace --debug

samples:
	# Grab the samples from the ffmpeg site.
	rsync -vrltLW rsync://fate-suite.ffmpeg.org/fate-suite/ tests/samples/

test-assets: tests/assets/lenna.png tests/assets/320x240x4.mov tests/assets/1KHz.wav tests/assets/latm_stereo_to_51.ts tests/assets/mpeg2_field_encoding.ts
tests/assets/1KHz.wav:
	python scripts/generate_audio.py -c 2 -r 48000 -t 4 -a 0.5 -f 1000 $@
tests/assets/320x240x4.mov:
	python scripts/generate_video.py -s 320x240 -r 24 -b 200k -t 4 $@
tests/assets/latm_stereo_to_51.ts:
	rsync -vrltLW rsync://fate-suite.ffmpeg.org/fate-suite/aac/latm_stereo_to_51.ts $@
tests/assets/mpeg2_field_encoding.ts:
	rsync -vrltLW rsync://fate-suite.ffmpeg.org/fate-suite/mpeg2/mpeg2_field_encoding.ts $@
tests/assets/lenna.png:
	@ mkdir -p $(@D)
	wget -O $@ https://upload.wikimedia.org/wikipedia/en/2/24/Lenna.png

test: build test-assets
	nosetests -v

vagrant:
	vagrant box list | grep -q precise32 || vagrant box add precise32 http://files.vagrantup.com/precise32.box

vtest-ffmpeg: cythonize
	vagrant ssh ffmpeg -c /vagrant/scripts/vagrant-test

vtest-libav: cythonize
	vagrant ssh libav -c /vagrant/scripts/vagrant-test

vtest: vtest-ffmpeg vtest-libav

debug: build
	gdb python --args python -m examples.tutorial $(TEST_MOV)

clean: clean-build

clean-build:
	- rm -rf build
	- find av -name '*.so' -delete

clean-sandbox:
	- rm -rf sandbox/2013*
	- rm sandbox/last

clean-src:
	- rm -rf src

clean-all: clean-build clean-sandbox clean-src
	- make -C docs clean

docs: build
	PYTHONPATH=.. make -C docs html

deploy-docs: docs
	./scripts/sphinx-to-github docs
