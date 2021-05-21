#!/usr/bin/Rscript

source('automation_utils.R')

build_all()

writeLines('<html><head><meta http-equiv="refresh" content="0; url=https://kaalam.github.io/kaalam/index.html"></head></html>',
		   '../kaalam.github.io/index.html')

setwd('../kaalam.github.io/')

system('./auto_add_commit_push.sh')
