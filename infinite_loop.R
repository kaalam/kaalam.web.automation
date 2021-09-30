#!/usr/bin/Rscript


source('automation_utils.R')

# path <- paste(c(BLOG_FOLDERS$input, BLOG_FOLDERS$jekyllpath, DOC_FOLDERS$input, DOC_FOLDERS$jekyllpath, DOX1_FOLDERS$input,
#				DOX2_FOLDERS$input, KAAL_FOLDERS$input, KAAL_FOLDERS$jekyllpath, NEWS_FOLDERS$input, NEWS_FOLDERS$jekyllpath,
#				RCLI_FOLDERS$input, STAT_FOLDERS$input), collapse = ' ')
path <- paste(c(DOC_FOLDERS$input, DOC_FOLDERS$jekyllpath, DOX2_FOLDERS$input, KAAL_FOLDERS$input,
				KAAL_FOLDERS$jekyllpath, RCLI_FOLDERS$input, STAT_FOLDERS$input), collapse = ' ')

while (TRUE)
{
	build_all()
	upload_all()

	system(paste('inotifywait -e create,close_write,delete -r', path))
}
