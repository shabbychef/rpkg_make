# /usr/bin/r
#
# install package and build readme
#
# Created: 2017.03.21
# Copyright: Steven E. Pav, 2017
# Author: Steven E. Pav <steven@gilgamath.com>
# Comments: Steven E. Pav

suppressMessages(library(docopt))       # we need docopt (>= 0.3) as on CRAN

doc <- "Usage: build_readme.r [-v] [-p <PACKAGE>] INFILE OUTFILE 

-p PACKAGE --package=PACKAGE     Name of package.tgz to first install
-v --verbose                     Be more verbose
-h --help                        show this help text"

#opt <- docopt(doc,args='-p SharpeR_1.0.0.7000.tar.gz INP OUP')
opt <- docopt(doc)

install.packages(opt$package)

package <- gsub('_(\\d+)(\\.\\d+)*\\.tar\\.gz$','',basename(opt$package))

library(package,character.only=TRUE) 

library(knitr)
library(devtools)

setwd(dirname(opt$package))

if (require(knitr)) {
	knit(input=opt$INFILE,output=opt$OUTFILE)
}

#for vim modeline: (do not edit)
# vim:fdm=marker:fmr=FOLDUP,UNFOLD:cms=#%s:syn=r:ft=r
