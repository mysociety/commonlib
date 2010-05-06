#!/usr/bin/make

### SETUP #######

NAME       = simplexml44
PHPDIR     = class
PHP5DIR    = class5
DOCFILES   = doc/html/$(NAME).html
WEBROOT    = /home/ingo/dev/html/ister.org/ister.org
WEBDIR     = $(WEBROOT)/www/code/$(NAME)

### END SETUP ###

SHELL      = /bin/bash
CP         = /bin/cp
CPFLAGS    = -a
RM         = /bin/rm
CVS        = /usr/bin/cvs
TAR        = /bin/tar
TARFLAGS   = -cz

DEVDIR       = $(shell pwd)
DEVDIRNAME   = $(shell basename `pwd`)
ROOTDIR      = $(shell pwd | sed 's|\(.*/\)$(DEVDIRNAME)|\1|')
WEBDOCDIR    = $(WEBDIR)
PHPFILES     = $(wildcard $(PHPDIR)/*.php)
DISTFILES    = $(subst $(DISTROOT)/$(DISTDIR)-cvs/%.phpd,%.php,$(PHPFILES))
INSTALLFILES = $(subst $(PHPDIR)/,,$(PHPFILES))
LIBFILES     = IsterObject.php IsterObjectChecker.php IsterLogger.php IsterLoggerStd.php IsterLoggerDebug.php
LIB4FILES    = $(patsubst %,../lib/%,$(LIBFILES))
LIB5FILES    = $(patsubst %,../lib5/%,$(LIBFILES))
PEAR         = /home/ingo/Dev/php/PEAR

ifndef VERSION
VERSION = 0
endif

.PHONY : all
all: syntax dist copy cleanup


.PHONY : doc
doc:
	make -C doc NAME=$(NAME) DOTVERSION=$(DOTVERSION)


.PHONY : syntax
syntax:
	make -C $(PHPDIR) syntax
	make -C $(PHP5DIR) syntax	

#Test

.PHONY : tests
tests: test

.PHONY : test
test: syntax
	make -C test test PHPV=4

.PHONY : testinit
testinit:
	make -C test testinit

.PHONY : devtest
devtest:
	make -C test devtest

.PHONY : unittest
unittest:
	make -C test unittest



#installation

ifdef INSTALLDIR

.PHONY : install
install:
	test -d $(INSTALLDIR) || mkdir -p $(INSTALLDIR)
	$(CP) $(CPFLAGS) $(foreach FILE,$(INSTALLFILES),$(PHPDIR)/$(FILE)) $(INSTALLDIR)


.PHONY : uninstall
uninstall:
	cd $(INSTALLDIR); $(RM) $(INSTALLFILES)

endif

#build distribution

ifneq ($(VERSION),0)

DISTDIR    = $(NAME)-$(VERSION)
DISTROOT   = $(ROOTDIR)dist
DOTVERSION = $(subst _,.,$(VERSION))

.PHONY : dist
dist: doc
	@echo "make distribution $(DOTVERSION)..."
	$(CP) $(CPFLAGS) $(DEVDIR) $(DISTROOT)/$(DISTDIR)
	cd  $(DISTROOT)/$(DISTDIR); make -C ./class dist NAME=$(NAME) DOTVERSION=$(DOTVERSION)
	rm -rfv `find $(DISTROOT)/$(DISTDIR) -depth  -name '.svn' -print`
	cd $(DISTROOT) && $(TAR) $(TARFLAGS) -f $(DISTDIR).tar.gz $(DISTDIR)



.PHONY : copy
copy:
	test -d $(WEBDIR) || mkdir -p $(WEBDIR)
	$(RM) $(WEBDIR)/$(NAME)*.tar.gz
	$(CP) $(CPFLAGS) $(DISTROOT)/$(DISTDIR).tar.gz $(WEBDIR)
	$(CP) $(CPFLAGS) $(DOCFILES) $(WEBDOCDIR)
	echo "$(VERSION)" > $(WEBDIR)/version


.PHONY : cleanup
cleanup:
	@echo "cleaning up..."
	-$(RM) -rf $(DISTDIR)
	-$(RM) -rf $(DISTDIR)-cvs


.PHONY : clean
clean: cleanup
	make -C xml22-onefile clean
	-$(RM) -rf $(ROOTDIR)$(DISTDIR).tar.gz

endif


.PHONY: help
help:
	@echo "valid targets are:"
	@echo "all"
	@echo "syntax"
	@echo "test"
	@echo "install INSTALLDIR=<path>"
	@echo "dist VERSION=<MAJOR_MINOR_BUILD>"
