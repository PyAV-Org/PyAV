
SPHINXOPTS    =
SPHINXBUILD   = sphinx-build
BUILDDIR      = _build

ALLSPHINXOPTS   = -d $(BUILDDIR)/doctrees $(SPHINXOPTS) .

.PHONY: clean html open upload
.DEFAULT: html

includes.rst: includes.py $(shell find ../include ../av -name '*.pyx' -or -name '*.pxd')
	python $< > $@.tmp
	mv $@.tmp $@

error_table.rst: error_table.py ../av/error.pyx
	python $< > $@.tmp
	mv $@.tmp $@

clean:
	- rm -rf $(BUILDDIR)/*
	- rm includes.rst

html: includes.rst error_table.rst
	$(SPHINXBUILD) -b html $(ALLSPHINXOPTS) $(BUILDDIR)/html

test:
	$(SPHINXBUILD) -b doctest $(ALLSPHINXOPTS) $(BUILDDIR)/doctest

open:
	open _build/html/index.html

upload:
	rsync -avxP --delete _build/html/ docs.mikeboers.com:/srv/mikeboers.com/docs/httpdocs/pyav/develop/

