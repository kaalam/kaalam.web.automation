#!/usr/bin/Rscript


source('automation_utils.R')


BITMAP_EXTENSIONS  <- c('jpg', 'png')
STATIC_EXTENSIONS  <- c('css', 'html', 'js')
FONTS_EXTENSIONS   <- c('eot', 'otf', 'svg', 'ttf', 'woff', 'woff2')
CRAP_EXTENSIONS	   <- c('htc', 'ico', 'json', 'psd', 'scss', 'txt', 'xml')

KNOWN_EXTENSIONS   <- c(BITMAP_EXTENSIONS, STATIC_EXTENSIONS, FONTS_EXTENSIONS, CRAP_EXTENSIONS)

PATH_KNOWN_BITMAPS <- '~/kaalam.etc/web_security/known_bitmaps'
PATH_KNOWN_FONTS   <- '~/kaalam.etc/web_security/known_fonts'
PATH_KNOWN_JS	   <- '~/kaalam.etc/web_security/known_js'

hashed_folder	<- function(hash, name, type, found) data.frame(hash = hash, name = name, type = type, found = found, stringsAsFactors = FALSE)
warn_event		<- function(level, source, issue) data.frame(level = level, source = source, issue = issue, stringsAsFactors = FALSE)
stat_even		<- function(type, files, bytes, last) data.frame(type = type, files = files, bytes = bytes, last = last, stringsAsFactors = FALSE)

DF_BITMAPS		<- hashed_folder('', '', '', '')[-1, ]
DF_FONTS		<- hashed_folder('', '', '', '')[-1, ]
DF_JS			<- hashed_folder('', '', '', '')[-1, ]
DF_WARNINGS		<- warn_event('', '', '')[-1, ]
DF_STATS		<- stat_even('', '', '', '')[-1, ]

REX_PAT_NAM_EXT <- '^(.*/)([[:alnum:]_.-]+)\\.([[:alnum:]]+)$'


valid_url <- function(url)
{
	stop('Not implemented.')

	TRUE
}


valid_http <- function(http)
{
	stop('Not implemented.')

	TRUE
}


hash_folder <- function(pat)
{
	fn <- list.files(path = pat, full.names = TRUE, recursive = TRUE)

	if (length(fn) == 0) return(hashed_folder('', '', '', '')[-1, ])

	if (!all(grepl(REX_PAT_NAM_EXT, fn))) stop(paste('Unexpected file format in', pat))

	hashfile <- function(fn) digest::digest(fn, file = TRUE)

	df <- hashed_folder(hash  = sapply(fn, hashfile),
						name  = gsub(REX_PAT_NAM_EXT, '\\2', fn),
						type  = gsub(REX_PAT_NAM_EXT, '\\3', fn),
						found = '')

	rownames(df) <- NULL

	if (any(duplicated(df$hash))) stop(paste('Duplicated resources in', pat))

	df
}


extract_capture <- function(txt, capture, fn)
{
	# txt <- c('aaa bbb',
	#		 'aaa url("http://google.com")',
	#		 'aaa url("http://google.com") bbb url("http://ibm.com") ccc',
	#		 'url("http://google.com") bbb',
	#		 'url("http://google.com") bbb url("http://ibm.com") ccc url("http://moft.com")',
	#		 'url("http://google.com");url("http://ibm.com");url("http://moft.com")',
	#		 'bbb',
	#		 'url("http://google.com");url("http://ibm.com");url("http://moft.com")',
	#		 ';url("http://moft.com")',
	#		 'url("http://google.com")url("http://ibm.com");url("http://moft.com")zzz',
	#		 'url("http://google.com")')
	# capture <- extract_url
	# cat(paste(txt, collapse = '\n'))

	ix <- which(grepl(capture$signal, txt))

	if (length(ix) == 0) return(character(0))

	txt <- paste(c('top', txt[ix]), collapse = ' ')
	txt <- paste0(capture$neat, strsplit(txt, split = capture$signal)[[1]][-1])

	rex2 <- paste0('^(.*)(', capture$signal, ')(.*)$')
	rex3 <- paste0('^(.*)(', capture$signal, ')(.*)(', capture$signal, ')(.*)$')

	if (!all(grepl(rex2, txt))) stop ('internal 1')
	if ( any(grepl(rex3, txt))) stop ('internal 2')

	if (!all(grepl(capture$capture, txt))) stop(paste('Unexpected', capture$neat, 'syntax in', fn))

	sort(unique(gsub("'", '', gsub('"', '', gsub(capture$capture, '\\1', txt)))))
}


audit_css <- function(fn, web_source)
{
	extract_url	 <- list(signal = '\\<url\\>', neat = 'url', capture = '^.*\\<url\\>\\(([^)]*)\\).*$')
	extract_http <- list(signal = '\\<https?://', neat = 'http://', capture = '^.*\\<https?://([[:alnum:]_.-]+).*$')

	txt <- readLines(fn, warn = FALSE)

	urls <- extract_capture(txt, extract_url, fn)

	for (url in urls) {
		if (!valid_url(url)) DF_WARNINGS <<- rbind(DF_WARNINGS,
												   warn_event(level = 'WARN', source = web_source, issue = paste('Invalid url', url, 'in', fn)))
	}

	https <- extract_capture(txt, extract_http, fn)

	for (http in https) {
		if (!valid_http(http)) DF_WARNINGS <<- rbind(DF_WARNINGS,
													 warn_event(level = 'WARN', source = web_source, issue = paste('Invalid http', http, 'in', fn)))
	}
}


audit_html <- function(fn, web_source)
{
	stop('Not implemented.')
}


audit_bitmap <- function(fn, web_source)
{
	# system(paste('cp', fn, PATH_KNOWN_BITMAPS))
	#
	# return(T)

	hash <- digest::digest(fn, file = TRUE)

	if (nrow(DF_BITMAPS) == 0) DF_BITMAPS <<- hash_folder(PATH_KNOWN_BITMAPS)

	fn <- normalizePath(fn)

	ix <- which(DF_BITMAPS$hash == hash)

	if (length(ix) != 1)
	{
		DF_WARNINGS <<- rbind(DF_WARNINGS, warn_event(level = 'WARN', source = web_source, issue = paste('Unknown bitmap file', fn)))

		return(FALSE)
	}

	if (DF_BITMAPS$found[ix] == '') {
		DF_BITMAPS$found[ix] <<- fn
	} else {
		if (DF_BITMAPS$found[ix] != fn)
		{
			DF_WARNINGS <<- rbind(DF_WARNINGS, warn_event(level = 'NOTE', source = web_source, issue = paste('Multiple instances of bitmap', fn)))

			return(FALSE)
		}
	}

	TRUE
}


audit_js <- function(fn, web_source)
{
	hash <- digest::digest(fn, file = TRUE)

	if (nrow(DF_JS) == 0) DF_JS <<- hash_folder(PATH_KNOWN_JS)

	fn <- normalizePath(fn)

	ix <- which(DF_JS$hash == hash)

	if (length(ix) != 1)
	{
		DF_WARNINGS <<- rbind(DF_WARNINGS, warn_event(level = 'WARN', source = web_source, issue = paste('Unknown js', fn)))

		return(FALSE)
	}

	if (DF_JS$found[ix] == '') {
		DF_JS$found[ix] <<- fn
	} else {
		if (DF_JS$found[ix] != fn)
		{
			DF_WARNINGS <<- rbind(DF_WARNINGS, warn_event(level = 'NOTE', source = web_source, issue = paste('Multiple instances of js', fn)))

			return(FALSE)
		}
	}

	TRUE
}


audit_font <- function(fn, web_source)
{
	# system(paste('cp', fn, PATH_KNOWN_FONTS))
	#
	# return(T)

	hash <- digest::digest(fn, file = TRUE)

	if (nrow(DF_FONTS) == 0) DF_FONTS <<- hash_folder(PATH_KNOWN_FONTS)

	fn <- normalizePath(fn)

	ix <- which(DF_FONTS$hash == hash)

	if (length(ix) != 1)
	{
		DF_WARNINGS <<- rbind(DF_WARNINGS, warn_event(level = 'WARN', source = web_source, issue = paste('Unknown font file', fn)))

		return(FALSE)
	}

	if (DF_FONTS$found[ix] == '') {
		DF_FONTS$found[ix] <<- fn
	} else {
		if (DF_FONTS$found[ix] != fn)
		{
			DF_WARNINGS <<- rbind(DF_WARNINGS, warn_event(level = 'NOTE', source = web_source, issue = paste('Multiple instances of font', fn)))

			return(FALSE)
		}
	}

	TRUE
}


report_crap <- function(fn, web_source)
{
	DF_WARNINGS <<- rbind(DF_WARNINGS, warn_event(level = 'WARN', source = web_source, issue = paste('Crap file', normalizePath(fn))))
}


audit_static <- function(fn, ext, web_source)
{
	if (ext == 'js')   return(audit_js	(fn, web_source))
	if (ext == 'css')  return(audit_css (fn, web_source))
	if (ext == 'html') return(audit_html(fn, web_source))

	stop('What is this?')
}


audit_file <- function(fn, web_source)
{
	if (!grepl(REX_PAT_NAM_EXT, fn)) stop(paste('Unexpected file format', fn))

	ext <- gsub(REX_PAT_NAM_EXT, '\\3', fn)

	ll <- file.info(fn)

	bytes <- ll$size
	last  <- format(ll$mtime, format = '%Y-%m-%d %H:%M:%S')

	ix <- which(DF_STATS$type == ext)

	if (length(ix) == 0) DF_STATS <<- rbind(DF_STATS, stat_even(type = ext, files = 1, bytes = bytes, last = last))
	else {
		DF_STATS$files[ix] <<- DF_STATS$files[ix] + 1
		DF_STATS$bytes[ix] <<- DF_STATS$bytes[ix] + bytes
		DF_STATS$last [ix] <<- max(DF_STATS$last[ix], last)
	}

	if (!(ext %in% KNOWN_EXTENSIONS)) stop(paste('Unknown extension', ext, 'in', fn))

	if (ext %in% BITMAP_EXTENSIONS) audit_bitmap(fn, web_source)
	if (ext %in% STATIC_EXTENSIONS) audit_static(fn, ext, web_source)
	if (ext %in% FONTS_EXTENSIONS)	audit_font	(fn, web_source)
	if (ext %in% CRAP_EXTENSIONS)	report_crap (fn, web_source)
}


audit <- function(folders)
{
	cat('Auditing:', folders$output, '...')

	prev_wd <- setwd(normalizePath(folders$output))

	rex <- '^.*/kaalam\\.github\\.io/([[:alnum:]/_-]+)$'

	if (!grepl(rex, folders$output)) stop('Unexpected format in folders$output.')

	for (fn in list.files('.', recursive = T, full.names = T)) audit_file(fn, folders$web_source)

	setwd(prev_wd)

	cat(' done.\n')
}


colnames_toupper <- function(df)
{
	colnames(df) <- toupper(colnames(df))
	rownames(df) <- NULL
	df
}


invisible(sapply(ALL_FOLDERS, audit))

err <- try(sx <- gsub('^.*columns[[:blank:]]*([0-9]+)[[:blank:]]*;.*$', '\\1', system('stty -a | head -1', intern = T)), silent = TRUE)

if (class(err) != 'try-error' && length(sx) == 1) options(width = as.integer(sx))

cat('\n')

if (nrow(DF_WARNINGS) == 0) {
	cat('No errors, no warnings.\n')
} else{
	ix <- order(DF_WARNINGS$level, DF_WARNINGS$source, DF_WARNINGS$issue)
	print(colnames_toupper(DF_WARNINGS))
}

cat('\n')

if (nrow(DF_STATS) == 0) {
	cat('No statistics available.\n')
} else{
	ix <- order(DF_STATS$files, DF_STATS$type, decreasing = c(T, F), method = 'radix')
	print(colnames_toupper(DF_STATS[ix, ]))
}
