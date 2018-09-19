
SPHINXOPTS    =
SPHINXBUILD   = sphinx-build
BUILDDIR      = _build

ALLSPHINXOPTS   = -d $(BUILDDIR)/doctrees $(SPHINXOPTS) .

.PHONY: clean html open upload
.DEFAULT: html

includes.rst: includes.py $(shell find ../include ../av -name '*.pyx' -or -name '*.pxd')
	python includes.py > $@.tmp
	mv $@.tmp $@

clean:
	- rm -rf $(BUILDDIR)/*
	- rm includes.rst

html: includes.rst
	$(SPHINXBUILD) -b html $(ALLSPHINXOPTS) $(BUILDDIR)/html

test:
	$(SPHINXBUILD) -b doctest $(ALLSPHINXOPTS) $(BUILDDIR)/doctest

open:
	open _build/html/index.html

upload:
	rsync -avxP --delete _build/html/ docs.mikeboers.com:/srv/mikeboers.com/docs/httpdocs/pyav/develop/

