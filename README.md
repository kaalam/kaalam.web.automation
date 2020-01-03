## What is this?

This is just a set of scripts to create the kaalam.ai static website. There is a separation of concerns:

  - [document.source](https://github.com/kaalam/document.source) is the neat text (as markdown) and image source of the website. This is where authors should edit.
  - [kaalam.github.io](https://github.com/kaalam/kaalam.github.io) is the (automatically generated) github pages static content accessible as [kaalam.ai](https://kaalam.github.io/)
  - [this](https://github.com/kaalam/kaalam.web.automation) is the automation process creating the latter from the former.


## How does it work?

This is a set of R scripts using different static web creation technologies, mainly jekyll, doxygen and R to create the pages, rjazz and Jazz 0.1.07 to visualize and test them and Rscript to automate the process.

It is basically a hack to cover a first website with minimal investment in web technologies while we focus on C++ development of Jazz 0.4+

There is no support, guarantee of stability or documentation other than this file and the scripts themselves.

The scripts expect to be run from a folder structure including the repositories with their original names in a common folder:

  - document.source/
  - jazz-client/
  - jazz-server/
  - kaalam.github.io/
  - kaalam.web.automation/

Run

	cd <whatever>/kaalam.web.automation/
	./render_release.R

Will create the structure of kaalam.web.automation/ completely with the content of kaalam.web.automation/ (using jekyll), jazz-server/ (using doxygen) and jazz-client/ (using R and knitter)

Also running: ./build_upload.R will build and upload the content into a local Jazz server for development, ./infinite_loop.R does the same as build_upload automatically each time a file is modified using inotifywait.


## License

  For all third party software (too long to list) the original license applies. Everything is OSS.

  For the automation scripts, http://www.apache.org/licenses/LICENSE-2.0

  The documents can be found in [here](https://github.com/kaalam/document.source) and the following applies to them:

### The original documentation of the Jazz 0.1.07 server and client:

  Copyright 2016-2017 Banco Bilbao Vizcaya Argentaria, S.A.

This product includes software developed at

BBVA (https://www.bbva.com/)

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0


### New documentation of the Jazz 0.2.x, 0.3.x (deprecated) and 0.4+ server and client:

  (c) 2018-2020 The Authors of Jazz

  available under GNU Simpler Free Documentation License http://gplv3.fsf.org/sfdl-dd1.txt


### Kaalam website and blog:

  (c) 2018-2020 kaalam.ai

  available under GNU Simpler Free Documentation License http://gplv3.fsf.org/sfdl-dd1.txt
  For the automation parts:


## Support/contributing ...

There is no support or documentation for this other than this file. Anything may and will probably change. Use at your own risk.

Contributors are always welcome! Contribution is encouraged to focus on the valuable content: Jazz and the documentation source rather than here, unless you are an expert in web technologies and can deliver something much better.
