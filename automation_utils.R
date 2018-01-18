#> Functions used by all the scripts in kaalam.web.automation


DOXY_FOLDER_OUTPUT   <- '../kaalam.github.io/development/Jazz'
DOXY_FOLDER_DOXYFILE <- './doxygen'


library(rjazz)


jazz_host <- 'http://localhost'
jazz_port <- ':8888'


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

	cat(url)

	if (grepl('/index\\.html$', url))
	{
		host   <- rjazz:::.host.
		downlo <- RCurl::basicTextGatherer()

		url	   <- gsub('index\\.html$', '', url)
		upload <- charToRaw(url)

		cat(' +', url)

		if (RCurl::curlPerform(url			 = paste0(host, '//www.', block,'.assign_url/', web_source),
							   infilesize	 = length(upload),
							   readfunction	 = upload,
							   writefunction = downlo[[1]],
							   upload		 = TRUE,
							   customrequest = 'PUT') != 0) stop ('Http error status.')

		if (downlo$value() != '0') stop(paste('PUT function .assign_url failed :', upload))
	}

	cat('\n')
}


upload_site <- function(working_dir, web_source, url_prefix = web_source)
{
	prev_wd <- setwd(paste0(working_dir, '/_site'))

	for (fn in list.files('.', recursive = T, full.names = T)) upload_file(fn, web_source, url_prefix)

	setwd(prev_wd)
}


upload_folder <- function(working_dir, web_source, url_prefix = web_source)
{
	prev_wd <- setwd(working_dir)

	for (fn in list.files('.', recursive = T, full.names = T)) upload_file(fn, web_source, url_prefix)

	setwd(prev_wd)
}


build_doygen <- function(working_dir)
{
	prev_wd <- setwd(working_dir)

	system('doxygen')

	setwd(prev_wd)
}

set_jazz_host(paste0(jazz_host, jazz_port))
