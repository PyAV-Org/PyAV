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
	python setup.py build_ext --inplace

samples:
	# Grab the samples from the ffmpeg site.
	rsync -vrltLW rsync://fate-suite.ffmpeg.org/fate-suite/ tests/samples/

test: build
	nosetests -v

debug: build
	gdb python --args python -m examples.tutorial $(TEST_MOV)

clean:
	- rm -rf build
	- find av -name '*.so' -delete

clean-all: clean
	- make -C docs clean

docs: build
	PYTHONPATH=.. make -C docs html

deploy-docs: docs
	./scripts/sphinx-to-github docs
