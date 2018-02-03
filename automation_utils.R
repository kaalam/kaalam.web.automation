#> Functions used by all the scripts in kaalam.web.automation


BLOG_FOLDERS <- list(input		= '../document.source/blog',
					 output		= '../kaalam.github.io/blog',
					 jekyllpath = './jekyll_so-simple',
					 web_source	= '_blog_')

DOC_FOLDERS	 <- list(input		= '../document.source/jazz_reference',
					 output		= '../kaalam.github.io/jazz_reference',
					 jekyllpath	= './jekyll_documentation',
					 web_source	= '_doc_')

DOX1_FOLDERS <- list(input		= '../jazz-server/src',
					 output		= '../kaalam.github.io/develop_jazz01',
					 doxypath	= './doxygen1',
					 web_source	= '_doxy1_')

DOX2_FOLDERS <- list(input		= '../Jazz/server/src',
					 output		= '../kaalam.github.io/develop_jazz02',
					 doxypath	= './doxygen2',
					 web_source	= '_doxy2_')

KAAL_FOLDERS <- list(input		= '../document.source/kaalam',
					 excluderex = '.*/LICENSE.md$',
					 output		= '../kaalam.github.io/kaalam',
					 jekyllpath	= './jekyll_forty',
					 web_source	= '_kaal_')

NEWS_FOLDERS <- list(input		= '../document.source/news',
					 output		= '../kaalam.github.io/news',
					 jekyllpath	= './jekyll_evento',
					 web_source	= '_news_')

PYCL_FOLDERS <- list(input		= '../Jazz/pyjazz/doc/html',
					 output		= '../kaalam.github.io/pyjazz',
					 web_source	= '_pycli_')

RCLI_FOLDERS <- list(input		= '../Jazz/rjazz/doc/html',
					 output		= '../kaalam.github.io/rjazz',
					 web_source	= '_rcli_')

STAT_FOLDERS <- list(input		= './jazz_01x',
					 output		= '../kaalam.github.io/develop',
					 web_source	= '_stat_')

ALL_FOLDERS <- list(BLOG_FOLDERS, DOC_FOLDERS, DOX1_FOLDERS, DOX2_FOLDERS, KAAL_FOLDERS, NEWS_FOLDERS, PYCL_FOLDERS, RCLI_FOLDERS, STAT_FOLDERS)


library(rjazz)


jazz_host <- 'http://localhost'
jazz_port <- ':8888'


#>> Jazz 0.1.x uploading
upload_file <- function(fn, web_source, url_prefix = web_source)
{
	obj <- readBin(fn, 'raw', n = file.size(fn))

	type <- type_const[['BLOCKTYPE_RAW_MIME_TXT']]

	if (grepl('.*\\.css$',	fn)) type <- type_const[['BLOCKTYPE_RAW_MIME_CSS']]
	if (grepl('.*\\.gif$',	fn)) type <- type_const[['BLOCKTYPE_RAW_MIME_GIF']]
	if (grepl('.*\\.htm$',	fn)) type <- type_const[['BLOCKTYPE_RAW_MIME_HTML']]
	if (grepl('.*\\.html$', fn)) type <- type_const[['BLOCKTYPE_RAW_MIME_HTML']]
	if (grepl('.*\\.jpg$',	fn)) type <- type_const[['BLOCKTYPE_RAW_MIME_JPG']]
	if (grepl('.*\\.js$',	fn)) type <- type_const[['BLOCKTYPE_RAW_MIME_JS']]
	if (grepl('.*\\.json$', fn)) type <- type_const[['BLOCKTYPE_RAW_MIME_JSON']]
	if (grepl('.*\\.png$',	fn)) type <- type_const[['BLOCKTYPE_RAW_MIME_PNG']]

	url	  <- gsub('^\\.', paste0('/', url_prefix), fn)
	block <- create_web_resource(web_source, url, type, obj)

	if (grepl('/index\\.html$', url))
	{
		host   <- rjazz:::.host.
		downlo <- RCurl::basicTextGatherer()

		url	   <- gsub('index\\.html$', '', url)
		upload <- charToRaw(url)

		if (RCurl::curlPerform(url			 = paste0(host, '//www.', block,'.assign_url/', web_source),
							   infilesize	 = length(upload),
							   readfunction	 = upload,
							   writefunction = downlo[[1]],
							   upload		 = TRUE,
							   customrequest = 'PUT') != 0) stop ('Http error status.')

		if (downlo$value() != '0') stop(paste('PUT function .assign_url failed :', upload))
	}
}


#>> "Only if necessary" logic.
most_recent_in_path <- function(path)
{
	fn <- list.files(path = normalizePath(path), all.files = TRUE, full.names = TRUE, recursive = TRUE)

	if (length(fn) == 0) return (as.POSIXlt('1900-01-01'))

	max(file.info(fn)$mtime)
}

most_recent_uploaded <- function(web_source)
{
	src <- '_upl_dates_'
	if (!(src %in% list_sources())) return (as.POSIXlt('1900-01-02'))

	err <- try(date <- get_R_block(src, web_source), silent = TRUE)

	if (class(err) == 'try-error') return (as.POSIXlt('1900-01-02'))

	strptime(date, format = '%Y-%m-%d %H:%M:%S')
}

touch <- function(web_source)
{
	src <- '_upl_dates_'
	if (!(src %in% list_sources())) create_source(src)

	put_R_block(source = src, block_key = web_source, sexp = format(Sys.time(), format = '%Y-%m-%d %H:%M:%S'))
}

nothing_to_build <- function(folders, extra_input_path = NULL)
{
	srct <- most_recent_in_path(folders$input)
	dest <- most_recent_in_path(folders$output)

	if (is.null(extra_input_path)) ret <- dest > srct
	else {
		extt <- most_recent_in_path(extra_input_path)

		ret <- dest > srct & dest > extt
	}

	if (ret) cat('	(nothing to build)\n')

	ret
}

nothing_to_upload <- function(folders)
{
	srct <- most_recent_in_path (folders$output)
	dest <- most_recent_uploaded(folders$web_source)

	ret <- dest > srct

	if (ret) cat('	(nothing to upload)\n')

	ret
}


#>> Upload function logic.
upload <- function(folders, force = FALSE)
{
	cat('Uploading:', folders$output)

	if (!force & nothing_to_upload(folders)) return(invisible())

	cat(' ...')

	prev_wd <- setwd(normalizePath(folders$output))

	rex <- '^.*/kaalam\\.github\\.io/([[:alnum:]/_-]+)$'

	if (!grepl(rex, folders$output)) stop('Unexpected format in folders$output.')

	for (fn in list.files('.', recursive = T, full.names = T)) upload_file(fn, folders$web_source, gsub(rex, '\\1', folders$output))

	setwd(prev_wd)

	touch(folders$web_source)

	cat(' done.\n')
}


#>> Build using doxygen.
build_doygen <- function(folders, force = FALSE)
{
	if (!dir.exists(folders$output)) dir.create(folders$output, showWarnings = FALSE, recursive = TRUE)

	cat('Building:', folders$output)

	if (!force & nothing_to_build(folders)) return(invisible())

	cat(' ...')

	prev_wd <- setwd(normalizePath(folders$doxypath))

	system('doxygen')

	setwd(prev_wd)

	cat(' done.\n')
}


#>> Build using jekyll.
build_jekyll <- function(folders, force = FALSE, no_bundle = FALSE)
{
	if (!dir.exists(folders$output)) dir.create(folders$output, showWarnings = FALSE, recursive = TRUE)

	cat('Building:', folders$output)

	if (!force & nothing_to_build(folders, extra_input_path = folders$jekyllpath)) return(invisible())

	cat(' ...')

	input	<- normalizePath(folders$input)
	jekyll	<- normalizePath(folders$jekyllpath)
	output	<- normalizePath(folders$output)

	system(paste0('cp -rf ', input, '/* ', jekyll, '/'))

	if (!is.null(folders$excluderex))
	{
		fn <- list.files(path = jekyll, full.names = TRUE, recursive = TRUE)
		ix <- which(grepl(folders$excluderex, fn))
		if (length(ix) > 0) unlink(fn[ix])
	}

	prev_wd <- setwd(jekyll)

	if (no_bundle) system('jekyll build')
	else		   system('bundle exec jekyll build')

	system(paste0('rm -rf ', output, '/'))
	system(paste0('mv _site ', output))

	setwd(prev_wd)

	cat(' done.\n')
}


#>> Build just copying.
build_copy <- function(folders, force = FALSE)
{
	if (!dir.exists(folders$output)) dir.create(folders$output, showWarnings = FALSE, recursive = TRUE)

	cat('Building:', folders$output)

	if (!force & nothing_to_build(folders)) return(invisible())

	cat(' ...')

	system(paste0('cp -r ', normalizePath(folders$input), '/* ', normalizePath(folders$output), '/'), intern = TRUE)

	cat(' done.\n')
}


#>> Build all.
build_all <- function()
{
	build_jekyll(BLOG_FOLDERS)
	build_jekyll(DOC_FOLDERS)
	build_doygen(DOX1_FOLDERS)
	build_doygen(DOX2_FOLDERS)
	build_jekyll(KAAL_FOLDERS)
	build_jekyll(NEWS_FOLDERS, no_bundle = TRUE)
	build_copy(PYCL_FOLDERS)
	build_copy(RCLI_FOLDERS)
	build_copy(STAT_FOLDERS)
}


#>> Upload all.
upload_all <- function() sapply(ALL_FOLDERS, upload)


#>> Setup server.
set_jazz_host(paste0(jazz_host, jazz_port))
