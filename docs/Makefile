
SPHINXOPTS    =
SPHINXBUILD   = sphinx-build
BUILDDIR      = _build

ALLSPHINXOPTS   = -d $(BUILDDIR)/doctrees $(SPHINXOPTS) .

.PHONY: clean html open upload default

default: html


TAGFILE := _build/doxygen/tagfile.xml
$(TAGFILE) :
	./generate-tagfile -o $(TAGFILE)


TEMPLATES := $(wildcard api/*.py development/*.py)
RENDERED := $(TEMPLATES:%.py=_build/rst/%.rst)
_build/rst/%.rst: %.py $(TAGFILE) $(shell find ../include ../av -name '*.pyx' -or -name '*.pxd')
	@ mkdir -p $(@D)
	python $< > $@.tmp
	mv $@.tmp $@


clean:
	- rm -rf $(BUILDDIR)/*

html: $(RENDERED) $(TAGFILE)
	$(SPHINXBUILD) -b html $(ALLSPHINXOPTS) $(BUILDDIR)/html

test:
	PYAV_SKIP_DOXYLINK=1 $(SPHINXBUILD) -b doctest $(ALLSPHINXOPTS) $(BUILDDIR)/doctest

open:
	open _build/html/index.html

upload:
	rsync -avxP --delete _build/html/ pyav.org:/srv/pyav.org/www/httpdocs/docs/develop/

