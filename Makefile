LDFLAGS ?= ""
CFLAGS ?= "-O0"

.PHONY: default build cythonize clean clean-all info test fate-suite test-assets docs

default: build


build:
	CFLAGS=$(CFLAGS) LDFLAGS=$(LDFLAGS) python setup.py build_ext --inplace --debug

cythonize:
	python setup.py cythonize



wheel: build-mingw32
	python setup.py bdist_wheel

build-mingw32:
	# before running, set PKG_CONFIG_PATH to the pkgconfig dir of the ffmpeg build.
	# set PKG_CONFIG_PATH=D:\dev\3rd\media-autobuild_suite\local32\bin-video\ffmpegSHARED\lib\pkgconfig
	CFLAGS=$(CFLAGS) LDFLAGS=$(LDFLAGS) python setup.py build_ext --inplace -c mingw32
	mv *.pyd av



fate-suite:
	# Grab ALL of the samples from the ffmpeg site.
	rsync -vrltLW rsync://fate-suite.ffmpeg.org/fate-suite/ tests/assets/fate-suite/

test-assets: tests/assets/lenna.png tests/assets/320x240x4.mov tests/assets/1KHz.wav

tests/assets/1KHz.wav:
	python scripts/generate_audio.py -c 2 -r 48000 -t 4 -a 0.5 -f 1000 $@

tests/assets/320x240x4.mov:
	python scripts/generate_video.py -s 320x240 -r 24 -b 200k -t 4 $@

tests/assets/lenna.png:
	@ mkdir -p $(@D)
	wget -O $@ https://upload.wikimedia.org/wikipedia/en/2/24/Lenna.png

test: build test-assets
	python setup.py test



vagrant:
	vagrant box list | grep -q precise32 || vagrant box add precise32 http://files.vagrantup.com/precise32.box

vtest-ffmpeg: cythonize
	vagrant ssh ffmpeg -c /vagrant/scripts/vagrant-test

vtest-libav: cythonize
	vagrant ssh libav -c /vagrant/scripts/vagrant-test

vtest: vtest-ffmpeg vtest-libav



vendor/ffmpeg:
	git clone git://source.ffmpeg.org/ffmpeg.git vendor/ffmpeg

vendor/Doxyfile: vendor/ffmpeg
	cp vendor/ffmpeg/doc/Doxyfile vendor/
	echo "GENERATE_TAGFILE = ../tagfile.xml" >> vendor/Doxyfile

vendor/tagfile.xml: vendor/Doxyfile
	cd vendor/ffmpeg; doxygen ../Doxyfile

docs: build vendor/tagfile.xml
	PYTHONPATH=.. make -C docs html

deploy-docs: docs
	./scripts/sphinx-to-github docs



clean: clean-build

clean-build:
	- rm -rf build
	- find av -name '*.so' -delete

clean-sandbox:
	- rm -rf sandbox/201*
	- rm sandbox/last

clean-src:
	- rm -rf src

clean-docs:
	- rm vendor/Doxyfile
	- rm vendor/tagfile.xml
	- make -C docs clean

clean-all: clean-build clean-sandbox clean-src clean-docs
