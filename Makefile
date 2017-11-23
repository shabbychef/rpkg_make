######################
#
# One Makefile for all R packages
#
# should be sourced via
#
# PKG_NAME = pkg
# VMAJOR   = 0
# VMINOR   = 1
# VPATCH   = 3
# VDEV     = .9090
# include rpkg_make/Makefile
#
# Created: 2017.03.16
# Copyright: Steven E. Pav, 2017
# Author: Steven E. Pav
# SVN: $Id$
######################

PKG_NAME 					?= NO_PACKAGE_GIVEN

VERSION 					 = $(VMAJOR).$(VMINOR).$(VPATCH)$(VDEV)
TODAY 						:= $(shell date +%Y-%m-%d)

PKG_LCNAME 				:= $(shell echo $(PKG_NAME) | tr 'A-Z' 'a-z')
PKG_VERSION				:= $(VERSION)
PKG_SRC 					:= $(shell basename $(PWD))

RLIB_D 						?= ./.R/lib

PKG_TGZ 					 = $(PKG_NAME)_$(PKG_VERSION).tar.gz
PKG_INSTALLED 		 = .$(basename $(basename $(PKG_TGZ))).installed
PKG_CRANCHECK 		 = $(basename $(basename $(PKG_TGZ))).crancheck
DRAT_SENTINEL   	 = .drat_$(PKG_TGZ)

ALL_R   					 = $(wildcard R/*.[rR])

ifdef RPKG_USES_RCPP
ALL_CPP 					 = $(wildcard src/*.cpp)
SRC_CPP 					 = $(filter-out src/RcppExports%,$(ALL_CPP))
EXPORTS_CPP				 = $(filter src/RcppExports%,$(ALL_CPP))
EXPORTS_R					 = $(filter R/RcppExports%,$(ALL_R))
SRC_R   					 = $(filter-out R/RcppExports%,$(ALL_R))
endif

TEST_R  					 = $(wildcard tests/testthat/*.[rR])
CHECK_TMP 				 = .check_tmp

ALL_RD  					 = $(wildcard man/*.Rd)
ONE_RD  					 = $(word 1,$(ALL_RD))
PKG_DEPS 					 = $(ALL_CPP)
PKG_DEPS 					+= $(ALL_RD)
PKG_DEPS 					+= $(ALL_R)
PKG_DEPS 					+= $(TEST_R)
PKG_DEPS 					+= DESCRIPTION NAMESPACE

R_QPDF 						?= $(shell which qpdf)
R_GSCMD						?= $(shell which gs)
GS_QUALITY 				?= 'ebook'

GID 							?= $$UID
BUILD_FLAGS 			?= --compact-vignettes=both --resave-data=best
DOCKER_RUN_FLAGS 		= --user $$UID:$(GID)
DOCKER_ENV 				 = -e R_QPDF='$(R_QPDF)' -e R_GSCMD='$(R_GSCMD)' -e GS_QUALITY=$(GS_QUALITY) -e R_LIBS_USER='/opt/R/lib'
BUILD_ENV 				 = R_QPDF=$(R_QPDF) R_GSCMD=$(R_GSCMD) \
									 GS_QUALITY=$(GS_QUALITY)

DOCKER 						?= $(shell which docker)
DOCKER_IMG 				 = .docker_img

############## DEFAULT ##############

.DEFAULT_GOAL 	:= help

############## MARKERS ##############

.PHONY   : help targets
.PHONY   : build attributes document docker_img
.SUFFIXES: 
.PRECIOUS: $(DOCKER_IMG)
ifdef RPKG_USES_RCPP
.PRECIOUS: %.cpp 
endif

############ BUILD RULES ############

# this will have to change b/c of inclusion file names...
help:  ## generate this help message
	@grep -h -P '^(([^\s]+\s+)*([^\s]+))\s*:.*?##\s*.*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# thanks to http://stackoverflow.com/a/26339924/164611
targets:  ## print the targets of the makefile
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | \
		awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | \
		sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs

build : $(PKG_TGZ) ## build the package .tar.gz file

ifdef RPKG_USES_RCPP
attributes : $(EXPORTS_CPP) ## build the file src/RcppExports.cpp

$(EXPORTS_CPP) $(EXPORTS_R) : $(SRC_CPP)
	r -l Rcpp -e 'compileAttributes(".")'
	@[ -f $(EXPORTS_CPP) ] && touch $(EXPORTS_CPP) || true
	@[ -f $(EXPORTS_R) ] && touch $(EXPORTS_R) || true

$(ONE_RD) : $(EXPORTS_CPP)
	r -l devtools -e 'document(".");'
	@touch $@
else
$(ONE_RD) : $(EXPORTS_CPP)
	r -l devtools -e 'document(".");'
	@touch $@

endif

check_benv : $(DOCKER_IMG)  ## check the build environment
	@$(DOCKER) run -it --rm $(DOCKER_RUN_FLAGS) --volume $(PWD):/srv:ro $(DOCKER_ENV) \
		--entrypoint="R" $(USER)/$(PKG_LCNAME)-crancheck \
		"--slave" "-e" 'print(Sys.getenv("R_QPDF"));print(Sys.getenv("R_GSCMD"));print(Sys.getenv("GS_QUALITY"));'

$(PKG_TGZ) : $(PKG_DEPS) $(DOCKER_IMG)
	$(call WARN_DEPS)
	$(DOCKER) run -it --rm $(DOCKER_RUN_FLAGS) --volume $(PWD):/srv:rw $(DOCKER_ENV) \
		--entrypoint="R" $(USER)/$(PKG_LCNAME)-crancheck \
		"CMD" "build" $(foreach stanza,$(BUILD_FLAGS),"$(stanza)") "/srv"
	@echo "if that don't work, then try:"
	@echo "r -l devtools -e 'build(".",path=".");'"

$(RLIB_D) :
	mkdir -p $@

# install the package into a local library using the docker image
$(PKG_INSTALLED) : .%.installed : %.tar.gz $(DOCKER_IMG) | $(RLIB_D)
	$(DOCKER) run -it --rm $(DOCKER_RUN_FLAGS) --volume $(PWD):/srv:ro \
		--volume $$(pwd $(RLIB_D)):/opt/R/lib:rw \
		$(DOCKER_ENV) \
		--entrypoint="r" $(USER)/$(PKG_LCNAME)-crancheck \
		"-e" "install.packages('$<',lib='/opt/R/lib')" > $@

installed : $(PKG_INSTALLED) ## install the package

rinstall : $(PKG_TGZ) ## install the package o nthe local machine, in default library.
	R CMD INSTALL $<

# use the installed package?
.%.useR : .%.installed $(DOCKER_IMG) | $(RLIB_D)
	$(DOCKER) run -it --rm $(DOCKER_RUN_FLAGS) --volume $$(pwd $(RLIB_D)):/opt/R/lib:rw \
		$(DOCKER_ENV) \
		--entrypoint="R" $(USER)/$(PKG_LCNAME)-crancheck 
	touch $@

document : $(ALL_RD) ## build Rd files

tools/figure :
	@mkdir -p $@

README.md : README.Rmd $(PKG_INSTALLED) | tools/figure
	r -l Rcpp -l knitr -l devtools -e 'setwd("$(<D)");if (require(knitr)) { knit("$(<F)") }'

docker_img : $(DOCKER_IMG) ## build the docker image

$(DOCKER_IMG) : docker/Dockerfile  
	$(DOCKER) build --rm -t $(USER)/$(PKG_LCNAME)-crancheck docker
	touch $@

%.crancheck : %.tar.gz $(DOCKER_IMG)
	$(eval CHECK_TMP:=$(shell mktemp -u .check_tmp_$(PKG_LCNAME)_XXXXXXXXXXXXXXXXXX))
	mkdir -p $(CHECK_TMP)
	$(DOCKER) run -it --rm $(DOCKER_RUN_FLAGS) --volume $(PWD):/srv:ro --volume $$(pwd $(CHECK_TMP))/$(CHECK_TMP):/tmp:rw $(USER)/$(PKG_LCNAME)-crancheck $< | tee $@
	@-cat $(CHECK_TMP)/$(PKG_NAME).Rcheck/00check.log | tee -a $@
	@-cat $(CHECK_TMP)/$(PKG_NAME).Rcheck/$(PKG_NAME)-Ex.timings | tee -a $@

check: $(PKG_CRANCHECK) ## check the package as CRAN.

DESCRIPTION : % : m4/%.m4 Makefile ## build the DESCRIPTION file
	m4 -I ./m4 -DVERSION=$(VERSION) -DDATE=$(TODAY) -DPKG_NAME=$(PKG_NAME) $< > $@

NAMESPACE : DESCRIPTION $(ALL_R) ## build the NAMESPACE file
	r -l roxygen2 -e 'if (require(roxygen2)) { roxygenize(package.dir="$(<D)") }'
	@-touch $@

coverage : installed ## compute package coverage
	R --vanilla -q --no-save -e 'if (require(covr)) { print(covr::package_coverage(".")) }'

# github tags

tag : ## advice on github tagging
	@-echo "git tag -a r$(VERSION) -m 'release $(VERSION)'"
	@-echo "git push --tags"

really_tag : ## actually github tag 
	git tag -a r$(VERSION) -m 'release $(VERSION)'
	git push --tags

untag : ## advice on github untagging
	@-echo "git tag --delete r$(VERSION)"
	@-echo "git push origin :r$(VERSION)"

# drat

$(DRAT_SENTINEL) : $(PKG_TGZ)
	@cd ~/github/drat && git pull origin gh-pages && cd -
	R --slave -e "drat:::insertPackage('$<',repodir='~/github/drat',commit=TRUE)"

dratit : $(DRAT_SENTINEL) ## insert into my drat store

viewit : README.md ## view the README.md locally
	$(DOCKER) run -d -p 0.0.0.0:9919:6419 --name $(PKG_LCNAME) -v $$(pwd):/srv/grip/wiki:ro shabbychef/grip
	xdg-open http://0.0.0.0:9919
	@echo "to stop, run"
	@echo 'docker rm $$(docker stop $(PKG_LCNAME))'

.PHONY : submodules 

# http://muddygoat.org/articles/git-submodules
submodules : ## refresh all git submodules, including rpkg_make
	git submodule foreach git checkout master
	git submodule foreach git pull

Rd2.pdf : $(ALL_RD) ## make pdf manual
	@-R CMD Rd2pdf --no-clean ./man

#for vim modeline: (do not edit)
# vim:ts=2:sw=2:tw=129:fdm=marker:fmr=FOLDUP,UNFOLD:cms=#%s:tags=.tags;:syn=make:ft=make:ai:si:cin:nu:fo=croqt:cino=p0t0c5(0:
