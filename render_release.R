#!/usr/bin/Rscript

source('automation_utils.R')

build_all()

setwd('../kaalam.github.io/')

system('./auto_add_commit_push.sh')
