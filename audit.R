#!/usr/bin/Rscript


source('automation_utils.R')


BITMAP_EXTENSIONS <- c('jpg', 'png')
STATIC_EXTENSIONS <- c('css', 'html', 'js')
FONTS_EXTENSIONS  <- c('eot', 'otf', 'svg', 'ttf', 'woff', 'woff2')
CRAP_EXTENSIONS	  <- c('htc', 'ico', 'json', 'psd', 'scss', 'txt', 'xml')

KNOWN_EXTENSIONS <- c(BITMAP_EXTENSIONS, STATIC_EXTENSIONS, FONTS_EXTENSIONS, CRAP_EXTENSIONS)


# audit_http <- function()
# {
#	txt <- system('grep -r jekyll* -e http', intern = TRUE)
#
#	txt <- txt[!grepl('^Binary file', txt)]
#
#	txt <- c(txt, 'test.txt: http://www.google.com http://www.ibm.com/hello.htm kwap https://kaalam.ai')
#
#	rex <- '^([^:]+):(?!http)*https?://([[:alnum:]_\\.]+)[ :/]?(.*)$'
#
#	df <- data.frame(filename = character(0), host = character(0))
#
#	ix <- which(grepl(rex, txt, perl = TRUE))
#
#	while (length(ix) > 0)
#	{
#		df <- rbind(df, data.frame(filename = gsub(rex, '\\1', txt[ix]), host = gsub(rex, '\\2', txt[ix])))
#
#		txt[ix] <- paste0(gsub(rex, '\\1', txt[ix]), ': ', gsub(rex, '\\3', txt[ix]))
#
#		ix <- which(grepl(rex, txt))
#	}
#
#	txt[!grepl(rex, txt)]
#	View(data.frame(txt = ))
#
#
#
# }

audit_bitmap <- function(fn, websource)
{
	stop('Not implemented.')
}


audit_static <- function(fn, pat, nam, ext, websource)
{
	stop('Not implemented.')
}


audit_font <- function(fn, websource)
{
	stop('Not implemented.')
}


report_crap <- function(fn, websource)
{
	stop('Not implemented.')
}


audit_file <- function(fn, web_source)
{
	rex <- '^(.*/)([[:alnum:]_.-]+)\\.([[:alnum:]]+)$'

	if (!grepl(rex, fn)) stop(paste('Unexpected file format', fn))

	pat <- gsub(rex, '\\1', fn)
	nam <- gsub(rex, '\\2', fn)
	ext <- gsub(rex, '\\3', fn)

	if (!(ext %in% KNOWN_EXTENSIONS)) stop(paste('Unknown extension', ext, 'in', fn))

	if (ext %in% BITMAP_EXTENSIONS) audit_bitmap(fn, websource)
	if (ext %in% STATIC_EXTENSIONS) audit_static(fn, pat, nam, ext, websource)
	if (ext %in% FONTS_EXTENSIONS)	audit_font (fn, websource)
	if (ext %in% CRAP_EXTENSIONS)	report_crap(fn, websource)
}


audit <- function(folders)
{
	cat('Learning:', folders$input, '...')



	cat(' done.\n')

	cat('Auditing:', folders$output, '...')

	prev_wd <- setwd(normalizePath(folders$output))

	rex <- '^.*/kaalam\\.github\\.io/([[:alnum:]/_-]+)$'

	if (!grepl(rex, folders$output)) stop('Unexpected format in folders$output.')

	for (fn in list.files('.', recursive = T, full.names = T)) audit_file(fn, folders$web_source)

	setwd(prev_wd)

	cat(' done.\n')
}


invisible(sapply(ALL_FOLDERS, audit))
