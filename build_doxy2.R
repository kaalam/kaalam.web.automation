#!/usr/bin/Rscript

source('automation_utils.R')

build_doxygen(DOX2_FOLDERS)

cat(readLines('doxygen2/doxy.warnings.txt'), sep = '\n')
