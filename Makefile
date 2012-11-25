
CYTHON_SRC = av/tutorial.pyx
C_SRC = $(CYTHON_SRC:%.pyx=build/%.c)
MOD_SOS = $(CYTHON_SRC:%.pyx=%.so)

.PHONY: default build cythonize clean info test

default: build

info:
	@ echo Cython sources: $(CYTHON_SRC)

cythonize: $(C_SRC)

build/%.c: %.pyx
	@ mkdir -p $(shell dirname $@)
	cython -I headers -o $@ $<

build: cythonize
	python setup.py build_ext --inplace

test: build
	python -m examples.tutorial sandbox/GOPR0015-small.MP4

debug: build
	gdb python --args python -m examples.tutorial sandbox/GOPR0015.MP4

clean:
	- rm -rf build
	- rm $(MOD_SOS)

