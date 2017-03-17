######################
#
# One Makefile for all R packages
#
# Created: 2017.03.16
# Copyright: Steven E. Pav, 2017
# Author: Steven E. Pav
# SVN: $Id$
######################

.DEFAULT_GOAL 	:= help

# this will have to change b/c of inclusion file names...
help:  ## generate this help message
	@grep -P '^(([^\s]+\s+)*([^\s]+))\s*:.*?##\s*.*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

#for vim modeline: (do not edit)
# vim:ts=2:sw=2:tw=79:fdm=marker:fmr=FOLDUP,UNFOLD:cms=#%s:tags=.tags;:syn=make:ft=make:ai:si:cin:nu:fo=croqt:cino=p0t0c5(0:
