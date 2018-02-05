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
PATH_KNOWN_URL	   <- '~/kaalam.etc/web_security/known_urls.txt'
PATH_KNOWN_DOMAINS <- '~/kaalam.etc/web_security/known_domains.txt'
PATH_BLACKLISTED   <- '~/kaalam.etc/web_security/blacklisted_words.txt'

REX_PAT_NAM_EXT <- '^(.*/)([[:alnum:]_.-]+)\\.([[:alnum:]]+)$'

hashed_folder <- function(hash, name, type, found) data.frame(hash = hash, name = name, type = type, found = found, stringsAsFactors = FALSE)
warn_event	  <- function(level, source, issue) data.frame(level = level, source = source, issue = issue, stringsAsFactors = FALSE)
stat_event	  <- function(type, files, bytes, last) data.frame(type = type, files = files, bytes = bytes, last = last, stringsAsFactors = FALSE)

GLOBAL <- new.env()


load_globals <- function()
{
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

	GLOBAL$bitmaps <- hash_folder(PATH_KNOWN_BITMAPS)
	GLOBAL$jscript <- hash_folder(PATH_KNOWN_JS)
	GLOBAL$fonts   <- hash_folder(PATH_KNOWN_FONTS)

	load_text <- function(fn) sort(unique(gsub('[[:blank:]]', '', readLines(fn))))

	GLOBAL$known_urls	 <- load_text(PATH_KNOWN_URL)
	GLOBAL$known_domains <- load_text(PATH_KNOWN_DOMAINS)
	GLOBAL$blacklisted	 <- load_text(PATH_BLACKLISTED)

	GLOBAL$warnings <- warn_event('', '', '')[-1, ]
	GLOBAL$stats	<- stat_event('', '', '', '')[-1, ]
}


nice <- function(s, max_len = 35)
{
	if (nchar(s) <= max_len) return(s)

	paste0('(..) ', substr(s, nchar(s) - max_len + 6, nchar(s)))
}


valid_url <- function(url)
{
	url %in% GLOBAL$known_urls
}


valid_http <- function(http)
{
	rex <- '^(.+)/(.*)$'

	if (grepl(rex, http)) http <- gsub(rex, '\\1', http)

	http %in% GLOBAL$known_domains
}


warning <- function(level, source, issue)
{
	GLOBAL$warnings <- rbind(GLOBAL$warnings, warn_event(level, source, issue))
}


extract_capture <- function(txt, capture, fn, web_source)
{
	ix <- which(grepl(capture$signal, txt))

	if (length(ix) == 0) return(character(0))

	txt <- paste(c('top', txt[ix]), collapse = ' ')
	txt <- paste0(capture$neat, strsplit(txt, split = capture$signal)[[1]][-1])

	rex2 <- paste0('^(.*)(', capture$signal, ')(.*)$')
	rex3 <- paste0('^(.*)(', capture$signal, ')(.*)(', capture$signal, ')(.*)$')

	if (!all(grepl(rex2, txt))) stop ('internal 1')
	if ( any(grepl(rex3, txt))) stop ('internal 2')

	if (all(grepl(capture$capture, txt))) return(sort(unique(gsub("'", '', gsub('"', '', gsub(capture$capture, '\\1', txt))))))

	ix <- which(!grepl(capture$capture, txt))

	for (tx in txt[ix]) warning(level = 'WARN', source = web_source, issue = paste('Cannot capture in', nice(tx), 'in', nice(fn)))

	ix <- which(grepl(capture$capture, txt))

	if (length(ix) == 0) return(character(0))

	sort(unique(gsub("'", '', gsub('"', '', gsub(capture$capture, '\\1', txt[ix])))))
}


audit_css <- function(fn, web_source)
{
	extract_url	 <- list(signal = '\\<url\\>', neat = 'url', capture = '^.*\\<url\\>\\(([^)]*)\\).*$')
	extract_http <- list(signal = '\\<https?://', neat = 'http://', capture = '^.*\\<https?://([[:alnum:]_.-]+).*$')

	txt <- readLines(fn, warn = FALSE)

	urls <- extract_capture(txt, extract_url, fn, web_source)

	for (url in urls) {
		if (!valid_url(url)) warning(level = 'WARN', source = web_source, issue = paste('Invalid url', nice(url), 'in', nice(fn)))
	}

	https <- extract_capture(txt, extract_http, fn, web_source)

	for (http in https) {
		if (!valid_http(http)) warning(level = 'WARN', source = web_source, issue = paste('Invalid domain in', nice(http), 'in', nice(fn)))
	}
}


audit_html <- function(fn, web_source)
{
	extract_http <- list(signal = '\\<https?://', neat = 'http://', capture = '^.*\\<https?://([[:alnum:]_.-]+).*$')

	txt <- readLines(fn, warn = FALSE)

	https <- extract_capture(txt, extract_http, fn, web_source)

	for (http in https) {
		if (!valid_http(http)) warning(level = 'WARN', source = web_source, issue = paste('Invalid domain in', nice(http), 'in', nice(fn)))
	}

	txt <- tolower(txt)
	txt <- gsub('[^[:alnum:]]', ' ', txt)
	txt <- paste(txt, collapse = ' ')
	txt <- strsplit(txt, split = ' ')[[1]]
	txt <- sort(unique(txt))
	txt <- txt[txt != '']

	ix <- which(txt %in% GLOBAL$blacklisted)

	for (i in ix) warning(level = 'WARN', source = web_source, issue = paste('Blacklisted word', nice(txt[i]), 'in', nice(fn)))
}


audit_bitmap <- function(fn, web_source)
{
	fn	 <- normalizePath(fn)
	hash <- digest::digest(fn, file = TRUE)

	ix <- which(GLOBAL$bitmaps$hash == hash)

	if (length(ix) == 1) {
		if (GLOBAL$bitmaps$found[ix] == '') GLOBAL$bitmaps$found[ix] <- fn
		else {
			if (GLOBAL$bitmaps$found[ix] != fn) warning(level = 'NOTE', source = web_source, issue = paste('Multiple instances of bitmap', nice(fn)))
		}
	} else warning(level = 'WARN', source = web_source, issue = paste('Unknown bitmap file', nice(fn)))
}


audit_js <- function(fn, web_source)
{
	fn	 <- normalizePath(fn)
	hash <- digest::digest(fn, file = TRUE)

	ix <- which(GLOBAL$jscript$hash == hash)

	if (length(ix) == 1) {
		if (GLOBAL$jscript$found[ix] == '') GLOBAL$jscript$found[ix] <- fn
		else {
			if (GLOBAL$jscript$found[ix] != fn) warning(level = 'NOTE', source = web_source, issue = paste('Multiple instances of js', nice(fn)))
		}
	} else warning(level = 'WARN', source = web_source, issue = paste('Unknown js file', nice(fn)))
}


audit_font <- function(fn, web_source)
{
	fn	 <- normalizePath(fn)
	hash <- digest::digest(fn, file = TRUE)

	ix <- which(GLOBAL$fonts$hash == hash)

	if (length(ix) == 1) {
		if (GLOBAL$fonts$found[ix] == '') GLOBAL$fonts$found[ix] <- fn
		else {
			if (GLOBAL$fonts$found[ix] != fn) warning(level = 'NOTE', source = web_source, issue = paste('Multiple instances of font', nice(fn)))
		}
	} else warning(level = 'WARN', source = web_source, issue = paste('Unknown font file', nice(fn)))
}


audit_static <- function(fn, ext, web_source)
{
	if (ext == 'js')   return(audit_js	(fn, web_source))
	if (ext == 'css')  return(audit_css (fn, web_source))
	if (ext == 'html') return(audit_html(fn, web_source))

	stop('Unsupported extension.')
}


audit_file <- function(fn, web_source)
{
	if (!grepl(REX_PAT_NAM_EXT, fn)) stop(paste('Unexpected file format', fn))

	ext <- gsub(REX_PAT_NAM_EXT, '\\3', fn)

	ll <- file.info(fn)

	bytes <- ll$size
	last  <- format(ll$mtime, format = '%Y-%m-%d %H:%M:%S')

	ix <- which(GLOBAL$stats$type == ext)

	if (length(ix) == 0) GLOBAL$stats <- rbind(GLOBAL$stats, stat_event(type = ext, files = 1, bytes = bytes, last = last))
	else {
		GLOBAL$stats$files[ix] <- GLOBAL$stats$files[ix] + 1
		GLOBAL$stats$bytes[ix] <- GLOBAL$stats$bytes[ix] + bytes
		GLOBAL$stats$last [ix] <- max(GLOBAL$stats$last[ix], last)
	}

	if (!(ext %in% KNOWN_EXTENSIONS)) stop(paste('Unknown extension', ext, 'in', fn))

	if (ext %in% BITMAP_EXTENSIONS) audit_bitmap(fn, web_source)
	if (ext %in% STATIC_EXTENSIONS) audit_static(fn, ext, web_source)
	if (ext %in% FONTS_EXTENSIONS)	audit_font	(fn, web_source)
	if (ext %in% CRAP_EXTENSIONS)	warning (level = 'WARN', source = web_source, issue = paste('Crap file', fn))
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


doit <- function()
{
	invisible(sapply(ALL_FOLDERS, audit))

	err <- try(sx <- gsub('^.*columns[[:blank:]]*([0-9]+)[[:blank:]]*;.*$', '\\1', system('stty -a | head -1', intern = T)), silent = TRUE)

	if (class(err) != 'try-error' && length(sx) == 1) options(width = as.integer(sx))

	colnames_toupper <- function(df) {colnames(df) <- toupper(colnames(df)); rownames(df) <- NULL; df}

	cat('\n')

	if (nrow(GLOBAL$warnings) == 0) {
		cat('No errors, no warnings.\n')
	} else{
		ix <- order(GLOBAL$warnings$level, GLOBAL$warnings$source, GLOBAL$warnings$issue)
		print(colnames_toupper(GLOBAL$warnings))
	}

	cat('\n')

	if (nrow(GLOBAL$stats) == 0) {
		cat('No statistics available.\n')
	} else{
		ix <- order(GLOBAL$stats$files, GLOBAL$stats$type, decreasing = c(T, F), method = 'radix')
		print(colnames_toupper(GLOBAL$stats[ix, ]))
	}
}


load_globals()
doit()
