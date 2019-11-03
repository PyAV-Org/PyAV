
SPHINXOPTS    =
SPHINXBUILD   = sphinx-build
BUILDDIR      = _build

ALLSPHINXOPTS   = -d $(BUILDDIR)/doctrees $(SPHINXOPTS) .

.PHONY: clean html open upload
.DEFAULT: html

TEMPLATES := $(wildcard api/*.py development/*.py)
RENDERED := $(TEMPLATES:%.py=_build/rst/%.rst)
_build/rst/%.rst: %.py $(shell find ../include ../av -name '*.pyx' -or -name '*.pxd')
	@ mkdir -p $(@D)
	python $< > $@.tmp
	mv $@.tmp $@

clean:
	- rm -rf $(BUILDDIR)/*

html: $(RENDERED)
	$(SPHINXBUILD) -b html $(ALLSPHINXOPTS) $(BUILDDIR)/html

test:
	$(SPHINXBUILD) -b doctest $(ALLSPHINXOPTS) $(BUILDDIR)/doctest

open:
	open _build/html/index.html

upload:
	rsync -avxP --delete _build/html/ docs.mikeboers.com:/srv/mikeboers.com/docs/httpdocs/pyav/develop/

