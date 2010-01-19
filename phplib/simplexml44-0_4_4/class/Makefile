#!/usr/bin/make

# $Id: Makefile,v 1.1 2007-06-19 18:06:33 francis Exp $

SHELL     = /bin/sh
PHP       = /usr/bin/php
PHPFLAGS  = -n -d html_errors=0 -l
M4        = /usr/bin/m4
M4FLAGS   = -P --define=M4YEAR=`date +"%Y"` --define=M4NAME=$(NAME) --define=M4VERSION=$(DOTVERSION)

PHPFILES        = $(wildcard *.php)
SYNTAXFILES     = $(patsubst %.php,%.stx,$(PHPFILES))
DISTFILES       = $(patsubst %.php,%.phpd,$(PHPFILES))

.PHONY : syntax
syntax: $(SYNTAXFILES)

.PHONY : predist
predist:
	cp ../LICENSE.m4 .

.PHONY : dist
dist: predist $(DISTFILES)
	rm LICENSE.m4

%.stx: %.php
	@$(PHP) $(PHPFLAGS) $< 2> /dev/null

%.phpd: %.php
	$(M4) $(M4FLAGS) $< > $@
	cp $@ $<
	rm $@