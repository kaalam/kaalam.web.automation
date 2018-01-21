#!/usr/bin/Rscript

source('automation_utils.R')

build_jekyll(NEWS_FOLDERS, no_bundle = TRUE)
