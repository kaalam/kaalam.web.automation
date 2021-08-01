#!/usr/bin/Rscript

source('automation_utils.R')

build_all()

writeLines('<html><head><meta http-equiv="refresh" content="0; url=https://kaalam.github.io/kaalam/index.html"></head></html>', '../kaalam.github.io/index.html')

system('cd ~/kaalam.etc/web_security/known_js/ && cd ~/kaalam.etc/web_security/known_js/')

system('./audit.R && cd ../kaalam.github.io/ && ./auto_add_commit_push.sh')
