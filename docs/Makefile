
SPHINXOPTS    =
SPHINXBUILD   = sphinx-build
BUILDDIR      = _build
FFMPEGDIR     = _ffmpeg

ALLSPHINXOPTS   = -d $(BUILDDIR)/doctrees $(SPHINXOPTS) .

.PHONY: clean html open upload default

default: html


TAGFILE := _build/doxygen/tagfile.xml
$(TAGFILE) :
	git clone --depth=1 git://source.ffmpeg.org/ffmpeg.git $(FFMPEGDIR)
	./generate-tagfile --library $(FFMPEGDIR) -o $(TAGFILE)


TEMPLATES := $(wildcard api/*.py development/*.py)
RENDERED := $(TEMPLATES:%.py=_build/rst/%.rst)
_build/rst/%.rst: %.py $(TAGFILE) $(shell find ../include ../av -name '*.pyx' -or -name '*.pxd')
	@ mkdir -p $(@D)
	python $< > $@.tmp
	mv $@.tmp $@


clean:
	rm -rf $(BUILDDIR) $(FFMPEGDIR)

html: $(RENDERED) $(TAGFILE)
	$(SPHINXBUILD) -b html $(ALLSPHINXOPTS) $(BUILDDIR)/html

test:
	PYAV_SKIP_DOXYLINK=1 $(SPHINXBUILD) -b doctest $(ALLSPHINXOPTS) $(BUILDDIR)/doctest

open:
	open _build/html/index.html

upload:
	rsync -avxP --delete _build/html/ root@basswood-io.com:/var/www/pyav/docs/develop

