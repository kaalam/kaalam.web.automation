#!/usr/bin/Rscript


audit_http <- function()
{
	txt <- system('grep -r jekyll* -e http', intern = TRUE)

	txt <- txt[!grepl('^Binary file', txt)]

	txt <- c(txt, 'test.txt: http://www.google.com http://www.ibm.com/hello.htm kwap https://kaalam.ai')

	rex <- '^([^:]+):(?!http)*https?://([[:alnum:]_\\.]+)[ :/]?(.*)$'

	df <- data.frame(filename = character(0), host = character(0))

	ix <- which(grepl(rex, txt, perl = TRUE))

	while (length(ix) > 0)
	{
		df <- rbind(df, data.frame(filename = gsub(rex, '\\1', txt[ix]), host = gsub(rex, '\\2', txt[ix])))

		txt[ix] <- paste0(gsub(rex, '\\1', txt[ix]), ': ', gsub(rex, '\\3', txt[ix]))

		ix <- which(grepl(rex, txt))
	}

	txt[!grepl(rex, txt)]
	View(data.frame(txt = ))



}

audit_known_js <- function()
{

}

audit_file_types <- function()
{

}
