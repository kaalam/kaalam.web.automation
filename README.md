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

  For the automation parts:

  This software may have been copy/pasted from some of our projects, in that case we recommend to use the supported project rather than this hack, otherwise, don't even mention the author.

  ... and, of course:

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


## Support/contributing ...

There is no support or documentation for this other than this file. Anything may and will probably change. Use at your own risk.

Contributors are always welcome! Contribution is encouraged to focus on the valuable content: Jazz and the documentation source rather than here, unless you are an expert in web technologies and can deliver something much better.
