#!/usr/bin/Rscript


source('automation_utils.R')


BITMAP_EXTENSIONS  <- c('jpg', 'png', 'ico')
STATIC_EXTENSIONS  <- c('css', 'html', 'js')
FONTS_EXTENSIONS   <- c('eot', 'otf', 'svg', 'ttf', 'woff', 'woff2')
OTHER_EXTENSIONS   <- c('htc', 'json', 'scss', 'txt', 'xml')

KNOWN_EXTENSIONS   <- c(BITMAP_EXTENSIONS, STATIC_EXTENSIONS, FONTS_EXTENSIONS, OTHER_EXTENSIONS)

PATH_KNOWN_BITMAPS <- '~/kaalam.etc/web_security/known_bitmaps'
PATH_KNOWN_FONTS   <- '~/kaalam.etc/web_security/known_fonts'
PATH_KNOWN_JS	   <- '~/kaalam.etc/web_security/known_js'
PATH_KNOWN_URL	   <- '~/kaalam.etc/web_security/known_urls.txt'
PATH_KNOWN_DOMAINS <- '~/kaalam.etc/web_security/known_domains.txt'
PATH_BLACKLISTED   <- '~/kaalam.etc/web_security/blacklisted_words.txt'

REX_PAT_NAM_EXT <- '^(.*/)([[:alnum:]_~\\.\\-]+)\\.([[:alnum:]]+)$'

hashed_folder <- function(hash, name, type, found) data.frame(hash = hash, name = name, type = type, found = found, stringsAsFactors = FALSE)
warn_event	  <- function(level, source, issue) data.frame(level = level, source = source, issue = issue, stringsAsFactors = FALSE)
stat_event	  <- function(type, files, bytes, last) data.frame(type = type, files = files, bytes = bytes, last = last, stringsAsFactors = FALSE)

extract_url	 <- list(signal = '\\<url\\>', neat = 'url', capture = '^.*\\<url\\>\\(([^)]*)\\).*$', except = '.*')
extract_http <- list(signal = '\\<https?://', neat = 'http://', capture = '^.*\\<https?://([[:alnum:]_/.-]+).*$', except = '^https?://"')

GLOBAL <- new.env()

COPY_BITMAPS <- FALSE
COPY_JS		 <- FALSE
COPY_FONTS	 <- FALSE


load_globals <- function() {
	hash_folder <- function(pat)
	{
		fn <- list.files(path = pat, full.names = TRUE, recursive = TRUE)

		if (length(fn) == 0) return (hashed_folder('', '', '', '')[-1, ])

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

	load_text <- function(fn) sort(unique(readLines(fn)))

	GLOBAL$known_urls	 <- load_text(PATH_KNOWN_URL)
	GLOBAL$known_domains <- load_text(PATH_KNOWN_DOMAINS)
	GLOBAL$blacklisted	 <- load_text(PATH_BLACKLISTED)

	GLOBAL$warnings <- warn_event('', '', '')[-1, ]
	GLOBAL$stats	<- stat_event('', '', '', '')[-1, ]
}


nice <- function(s, max_len = 60) {
	if (nchar(s) <= max_len) return (s)

	paste0('(..) ', substr(s, nchar(s) - max_len + 6, nchar(s)))
}


all_urls_domain <- data.frame(url = character(0), domain = character(0), stringsAsFactors = FALSE)

valid_url <- function(url) {
	url <- nice(url)

	if (url %in% GLOBAL$known_urls) return (TRUE)

	if (grepl('^[./]*[[:alnum:]/_-]+\\.(png|jpg)$', url)) return (TRUE)

	rex <- '^([^/]+)/(.*)$'

	domain <- '?'
	if (grepl(rex, url)) {
		domain <- gsub(rex, '\\1', url)

		if (domain %in% GLOBAL$known_domains) return (TRUE)
	}

	if (!(url %in% all_urls_domain$url)) {
		urls_domain <- data.frame(url = url, domain = domain, stringsAsFactors = FALSE)

		all_urls_domain <<- rbind(all_urls_domain, urls_domain)
	}

	FALSE
}


warning <- function(level, source, issue) {
	GLOBAL$warnings <- rbind(GLOBAL$warnings, warn_event(level, source, issue))
}


extract_capture <- function(txt, capture, fn, web_source) {
	ix <- which(grepl(capture$signal, txt))

	if (length(ix) == 0) return (character(0))

	txt <- paste(c('top', txt[ix]), collapse = ' ')
	txt <- paste0(capture$neat, strsplit(txt, split = capture$signal)[[1]][-1])

	rex2 <- paste0('^(.*)(', capture$signal, ')(.*)$')
	rex3 <- paste0('^(.*)(', capture$signal, ')(.*)(', capture$signal, ')(.*)$')

	if (!all(grepl(rex2, txt))) stop ('internal 1')
	if ( any(grepl(rex3, txt))) stop ('internal 2')

	if (all(grepl(capture$capture, txt))) return (sort(unique(gsub("'", '', gsub('"', '', gsub(capture$capture, '\\1', txt))))))

	ix <- which(!grepl(capture$capture, txt))

	for (tx in txt[ix]) {
		if (!grepl(capture$except, nice(tx))) {
			if (!(nice(tx) %in% GLOBAL$known_urls))
				warning (level = 'WARN', source = web_source, issue = paste('Cannot capture in', nice(tx), 'in', nice(fn)))
		}
	}

	ix <- which(grepl(capture$capture, txt))

	if (length(ix) == 0) return (character(0))

	sort(unique(gsub("'", '', gsub('"', '', gsub(capture$capture, '\\1', txt[ix])))))
}


audit_css <- function(fn, web_source) {
	txt <- readLines(fn, warn = FALSE)

	if (!SKIP_EXTRACT_URL_CSS)
	{
		urls <- extract_capture(txt, extract_url, fn, web_source)

		for (url in urls) {
			if (!valid_url(url)) warning (level = 'WARN', source = web_source, issue = paste('Invalid url', nice(url), 'in', nice(fn)))
		}
	}

	if (!SKIP_EXTRACT_HTTP_CSS)
	{
		https <- extract_capture(txt, extract_http, fn, web_source)

		for (url in https) {
			if (!valid_url(url)) warning (level = 'WARN', source = web_source, issue = paste('Invalid domain in', nice(url), 'in', nice(fn)))
		}
	}
}


audit_html <- function(fn, web_source) {
	txt <- readLines(fn, warn = FALSE)

	if (!SKIP_EXTRACT_HTTP_HTML)
	{
		https <- extract_capture(txt, extract_http, fn, web_source)

		for (url in https) {
			if (!valid_url(url)) warning (level = 'WARN', source = web_source, issue = paste('Invalid domain in', nice(url), 'in', nice(fn)))
		}
	}

	if (!SKIP_BLACKLISTED_HTML)
	{
		txt <- tolower(txt)
		txt <- gsub('[^[:alnum:]]', ' ', txt)
		txt <- paste(txt, collapse = ' ')
		txt <- strsplit(txt, split = ' ')[[1]]
		txt <- sort(unique(txt))
		txt <- txt[txt != '']

		ix <- which(txt %in% GLOBAL$blacklisted)

		for (i in ix) warning (level = 'WARN', source = web_source, issue = paste('Blacklisted word', nice(txt[i]), 'in', nice(fn)))
	}
}


audit_bitmap <- function(fn, web_source) {

	if (COPY_BITMAPS) system(paste0('cp ', fn, ' ', PATH_KNOWN_BITMAPS, '/'))

	fn	 <- normalizePath(fn)
	hash <- digest::digest(fn, file = TRUE)

	ix <- which(GLOBAL$bitmaps$hash == hash)

	if (length(ix) == 1) {
		if (GLOBAL$bitmaps$found[ix] == '') GLOBAL$bitmaps$found[ix] <- fn
		else {
			if (GLOBAL$bitmaps$found[ix] != fn & !SKIP_MULTIPLE_BITMAPS)
				warning (level = 'NOTE', source = web_source, issue = paste('Multiple instances of bitmap', nice(fn)))
		}
	} else if (!SKIP_KNOWN_BITMAPS) warning (level = 'WARN', source = web_source, issue = paste('Unknown bitmap file', nice(fn)))
}


audit_js <- function(fn, web_source) {

	if (COPY_JS) {
		system(paste0('cp ', fn, ' ', PATH_KNOWN_JS, '/', gsub('\\.', '', as.character(runif(1)*9e14)), '.js'))
		system(paste0('fdupes -d -N ', PATH_KNOWN_JS))
	}

	fn	 <- normalizePath(fn)
	hash <- digest::digest(fn, file = TRUE)

	ix <- which(GLOBAL$jscript$hash == hash)

	if (length(ix) == 1) {
		if (GLOBAL$jscript$found[ix] == '') GLOBAL$jscript$found[ix] <- fn
		else {
			if (GLOBAL$jscript$found[ix] != fn & !SKIP_MULTIPLE_JS)
				warning (level = 'NOTE', source = web_source, issue = paste('Multiple instances of js', nice(fn)))
		}
	} else if (!SKIP_KNOWN_JS) warning (level = 'WARN', source = web_source, issue = paste('Unknown js file', nice(fn)))
}


audit_font <- function(fn, web_source) {

	if (COPY_FONTS) {
		system(paste0('cp ', fn, ' ', PATH_KNOWN_FONTS, '/', gsub('\\.', '', as.character(runif(1)*9e14)), '.font'))
		system(paste0('fdupes -d -N ', PATH_KNOWN_FONTS))
	}

	fn	 <- normalizePath(fn)
	hash <- digest::digest(fn, file = TRUE)

	ix <- which(GLOBAL$fonts$hash == hash)

	if (length(ix) == 1) {
		if (GLOBAL$fonts$found[ix] == '') GLOBAL$fonts$found[ix] <- fn
		else {
			if (GLOBAL$fonts$found[ix] != fn & !SKIP_MULTIPLE_FONTS)
				warning (level = 'NOTE', source = web_source, issue = paste('Multiple instances of font', nice(fn)))
		}
	} else if (!SKIP_KNOWN_FONTS) warning (level = 'WARN', source = web_source, issue = paste('Unknown font file', nice(fn)))
}


remove_hidden_shit <- function(fn) {
	fn  <- normalizePath(fn)
	txt <- readLines(fn, warn = FALSE)
	rex <- '\xe2\x80\x8b'

	ix <- which(grepl(rex, txt))

	if (length(ix) == 0)
		return (invisible())

	txt[ix] <- gsub(rex, '', txt[ix])

	warning (level = 'NOTE', source = nice(fn), issue = 'Removed hidden shit')

	writeLines(txt, fn)
}


audit_static <- function(fn, ext, web_source) {
	remove_hidden_shit(fn)

	if (ext == 'js')   return (audit_js	(fn, web_source))
	if (ext == 'css')  return (audit_css (fn, web_source))
	if (ext == 'html') return (audit_html(fn, web_source))

	stop('Unsupported extension.')
}


audit_file <- function(fn, web_source) {

	# cat(sprintf('audit_file(fn:%s, web_source:%s)\n', fn, web_source))

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

	if (ext %in% OTHER_EXTENSIONS & !SKIP_CRAP_CHECK) warning (level = 'WARN', source = web_source, issue = paste('Crap file', fn))
}


audit <- function(folders) {

	if (folders$web_source %in% SKIP_WEB_SOURCES) cat('Skipping:', folders$output, '\n')
	else {
		cat('Auditing:', folders$output, '...')

		prev_wd <- setwd(normalizePath(folders$output))

		rex <- '^.*/kaalam\\.github\\.io/([[:alnum:]/_-]+)$'

		if (!grepl(rex, folders$output)) stop('Unexpected format in folders$output.')

		for (fn in list.files('.', recursive = T, full.names = T)) audit_file(fn, folders$web_source)

		setwd(prev_wd)

		cat(' done.\n')
	}
}


doit <- function() {

	failed <- TRUE

	invisible(sapply(ALL_FOLDERS, audit))

	err <- try(sx <- gsub('^.*columns[[:blank:]]*([0-9]+)[[:blank:]]*;.*$', '\\1', system('stty -a | head -1', intern = T)), silent = TRUE)

	if (class(err) != 'try-error' && length(sx) == 1) options(width = as.integer(sx))

	colnames_toupper <- function(df) {colnames(df) <- toupper(colnames(df)); rownames(df) <- NULL; df}

	cat('\n')

	if (nrow(GLOBAL$warnings) == 0) {
		failed <- FALSE

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

	if (failed)	{
		cat('\n')
		stop('Audit had issues, automatic pushing skipped')
	}
}


config <- function() {

	assign('SKIP_BLACKLISTED_HTML', FALSE, envir = .GlobalEnv)
	assign('SKIP_CRAP_CHECK',       FALSE, envir = .GlobalEnv)

	assign('SKIP_EXTRACT_HTTP_CSS',  FALSE, envir = .GlobalEnv)
	assign('SKIP_EXTRACT_HTTP_HTML', FALSE, envir = .GlobalEnv)
	assign('SKIP_EXTRACT_URL_CSS',   FALSE, envir = .GlobalEnv)

	assign('SKIP_KNOWN_BITMAPS', FALSE, envir = .GlobalEnv)
	assign('SKIP_KNOWN_FONTS',   FALSE, envir = .GlobalEnv)
	assign('SKIP_KNOWN_JS',      FALSE, envir = .GlobalEnv)

	assign('SKIP_MULTIPLE_BITMAPS', FALSE, envir = .GlobalEnv)
	assign('SKIP_MULTIPLE_FONTS',   FALSE, envir = .GlobalEnv)
	assign('SKIP_MULTIPLE_JS',      FALSE, envir = .GlobalEnv)

	assign('SKIP_WEB_SOURCES', '', envir = .GlobalEnv)

	if (file.exists('audit.conf.r')) {
		cat('Configuration file audit.conf.r found, containing:\n\n')
		cat(paste(readLines('audit.conf.r'), collapse = '\n'))
		cat('\n\nApplying configuration.\n\n')

		source('audit.conf.r', local = FALSE)

	} else cat('No configuration file audit.conf.r found, doing all checks to all web sources.\n\n')
}


args = commandArgs(trailingOnly = TRUE)

if (length(args) > 0) {
	if (any(!grepl('^copy_[a-z]+$', args))) stop('Usage: ./audit.R copy_bitmaps? copy_js? copy_fonts?')

	COPY_BITMAPS <- any(args == 'copy_bitmaps')
	COPY_JS		 <- any(args == 'copy_js')
	COPY_FONTS	 <- any(args == 'copy_fonts')
}

config()
load_globals()
doit()
