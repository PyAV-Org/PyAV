LDFLAGS ?= ""
CFLAGS ?= "-O0"

FFMPEG_VERSION = 2.7


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

test:
	python setup.py test



vagrant:
	vagrant box list | grep -q precise32 || vagrant box add precise32 http://files.vagrantup.com/precise32.box

vtest:
	vagrant ssh -c /vagrant/scripts/vagrant-test



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
	- rm tmp/Doxyfile
	- rm tmp/tagfile.xml
	- make -C docs clean

clean-all: clean-build clean-sandbox clean-src clean-docs
