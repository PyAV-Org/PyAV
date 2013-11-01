CYTHON_SRC = $(shell find av -name "*.pyx")
C_SRC = $(CYTHON_SRC:%.pyx=build/cython/%.c)
MOD_SOS = $(CYTHON_SRC:%.pyx=%.so)

TEST_MOV = sandbox/640x360.mp4

.PHONY: default build cythonize clean clean-all info test docs

default: build

info:
	@ echo Cython sources: $(CYTHON_SRC)

cythonize: $(C_SRC)

build/cython/%.c: %.pyx
	@ mkdir -p $(shell dirname $@)
	cython -I. -Iheaders -o $@ $<

build: cythonize
	CFLAGS=-O0 python setup.py build_ext --inplace --debug

samples:
	# Grab the samples from the ffmpeg site.
	rsync -vrltLW rsync://fate-suite.ffmpeg.org/fate-suite/ tests/samples/

test-assets: tests/assets/lenna.png tests/assets/320x240x4.mov
tests/assets/320x240x4.mov:
	python scripts/generate_video.py -s 320x240 -r 24 -t 4 $@
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

clean:
	- rm -rf build
	- find av -name '*.so' -delete

clean-sandbox:
	- rm -rf sandbox/2013*
	- rm sandbox/last

clean-all: clean clean-sandbox
	- make -C docs clean

docs: build
	PYTHONPATH=.. make -C docs html

deploy-docs: docs
	./scripts/sphinx-to-github docs
