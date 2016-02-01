# Makefile to control the generation of CEUR-WS.org proceedings volumes
#
# Part of ceur-make (https://github.com/ceurws/ceur-make/)
# 
# Note:
# * Some steps require further manual work.
# * There are still a lot of hard-coded assumptions in this implementation.
#
# © Christoph Lange and contributors 2012–2015
#
# Licensed under GPLv3 or any later version

PAPER_DIRECTORIES = 999?????

# reasonable defaults for things that Makefile.vars (see below) can override
MKDIR = mkdir
TEX2PDF = pdflatex
SHELL = /bin/bash

# You first need to copy Makefile.vars.template to Makefile.vars and adapt the paths.
include Makefile.vars

# By default, we want
# * the ceur-ws directory (including index.html and BibTeX)
# * a copyright form
# * a LaTeX table of contents
all: ceur-ws/index.html ceur-ws/temp.bib copyright-form.txt toc.tex

# creates a CEUR-WS.org compliant copyright form
copyright-form.txt: workshop.xml
	$(SAXON) $< copyright-form.xsl > $@

# creates a LaTeX table of contents for the optional all-in-one PDF (which is assumed to be named proc.pdf)
#
# This should be included into your proc.tex file via
# \input{toc}
#
# Note that for now you have to provide a sufficient LaTeX command \add{filename}{title}{authors}, which results in including the paper filename.pdf into your overall PDF file.  You may, e.g., use \includepdf from the pdfpages package to get this job done, as follows:
# \usepackage{pdfpages}
# \newcommand{\add}[4][]{\includepdf[#1,scale=1.0,addtotoc={1,addchap,0,#3\\ {#4},#2}]{#2}}
toc.tex: toc.xml
	$(SAXON) $< toc2latex.xsl > $@

# creates from an unzipped EasyChair proceedings archive the XML table of contents, from which any further files are generated
toc.xml:
	exec > $@ ; \
	echo '<toc>' ; \
	for i in $(PAPER_DIRECTORIES) ; \
	do \
		echo $$i >&2 ; \
		cd $$i ; \
		../easychair2xml.pl README_EASYCHAIR ; \
		cd .. ; \
	done; \
	echo '</toc>'

# creates a CEUR-WS.org compliant index.html file
ceur-ws/index.html: toc.xml workshop.xml ceur-ws/paper-01.pdf
	$(SAXON) $< toc2ceurindex.xsl \
	> $@

# # Old implementation of this rule, while US-ASCII output was required:
# # recode u8..h : assume UTF8-input; encode everything using HTML entities (e.g. © → &copy;)
# # recode h0.. : decode XML-standalone entities (e.g. &lt; → <)
# # effective result: HTML with all special characters encoded as entities
# ceur-ws/index.html: toc.xml workshop.xml ceur-ws/paper-01.pdf
# 	$(SAXON) $< toc2ceurindex.xsl \
#         | recode u8..h \
#         | recode h0..u8 \
#         > $@

# from workshop.xml, which you have to provide manually, this generates a file that contains the a shorthand identifier for this proceedings volume; this will be used to create some of the further filenames.
ID: workshop.xml
	$(SAXON) $< id.xsl > $@

# This rule creates ceur-ws/paper-PP.pdf symbolic links (01, 02, ...) to each paper, as well as a link to the all-in-one PDF, which is assumed to exist as proc.pdf in the current directory (and is not currently auto-generated by ceur-make).
#
# This setup is not necessarily suitable for multi-track proceedings, e.g. joint proceedings of more than one workshop, where one would rather prefer paper names such as track1-01.pdf, track1-02.pdf, track2-01.pdf, etc.
ceur-ws/paper-01.pdf: ceur-ws ID
	i=1 ; \
	for p in $(PAPER_DIRECTORIES) ; \
	do \
		[[ ! -e $$p/$$p.pdf ]] && break ; \
		ln -sfv ../$$p/$$p.pdf ceur-ws/paper-$$(printf "%02d" $$i).pdf ; \
		(( i++ )) ; \
	done ; \
	if [[ -e ../proc.pdf ]] ; then \
		ln -sfv ../proc.pdf ceur-ws/$$(< ID)-complete.pdf ; \
	fi

# creates a BibTeX file for the proceedings volume.  This file will probably need manual fine-tuning (e.g. for capitalization of titles and for non-ASCII characters), and needs to be copied to a file named by the actual identifier of the event.
ceur-ws/temp.bib: toc.xml workshop.xml ceur-ws ID
	$(SAXON) $< toc2bibtex.xsl > $@ ; \
	echo "Please copy $@ to ceur-ws/$$(< ID).bib and fine-tune manually"

# creates the ceur-ws subdirectory, which contains all files that will go into the actual proceedings volume, or links to such files, if they already exist in other places (e.g. in the EasyChair archive directories).
ceur-ws:
	-[[ ! -d ceur-ws ]] && $(MKDIR) ceur-ws

# At the moment, this rule only applies to bibtest.pdf and the proc.pdf all-in-one proceedings file, which is generated from a LaTeX source.  Later we may also use it for regenerating the individual papers (see below)
%.pdf: %.tex
	$(TEX2PDF) $<

# regenerates all papers from their LaTeX sources, as EasyChair would also do internally.
#
# Note that at the moment we don't respect the actual typesetting command (even though EasyChair records it in the README_EASYCHAIR files), e.g. this won't work for papers created via an intermediate DVI output, but we assume that everything goes to PDF directly.
retex:
	for i in $(PAPER_DIRECTORIES) ; \
	do \
		echo $$i ; \
		cd $$i ; \
		file=$$(perl -ne 'print $$1 if /^Command to create document: .*latex (.*)$$/' README_EASYCHAIR); \
		file=$${file%.tex}; \
		$(TEX2PDF) --jobname $$i $${file}.tex; \
		cd .. ; \
	done

# creates the ZIP file for upload to CEUR-WS.org
zip: ceur-ws/index.html ceur-ws/temp.bib
	zip -r $$(< ID).zip ceur-ws -x ceur-ws/temp.bib -i '*.html' '*.pdf' '*.bib'

# cleans up some files created by other rules
clean:
	rm $$(< ID).zip

# The names of the following rules are not names of files:
.PHONY: all zip retex clean
