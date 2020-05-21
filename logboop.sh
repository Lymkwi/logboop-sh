#!/bin/bash
# vim: set filetype:

INPUT_DIR=$1
OUTPUT_DIR=$2 || "./output"

MONTHS="Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec"

# The main function
# No param
main() {
	degunzip_all_the_files; # that's better on the CPU

	[ $? -eq 0 ] || (echo "hmm" && return 1);

	# Potential files usually have an extension .I where I is a positive integer.
	# Specifically, now that we have gunzip'd all the .gz files, only .I files remain.
	POTENTIAL_FILES=$(find $INPUT_DIR -type f | grep ".*\.[0-9].*")

	# Parse
	mkdir -p $OUTPUT_DIR || return 1;
	for FILE_PATH in $POTENTIAL_FILES; do
		parse $FILE_PATH
	done;

	# Gunzip all the files in $OUTPUT_DIR that don't have a '.gz' extension
	for FILE_PATH in $(find $OUTPUT_DIR -type f -not -iname '*.gz'); do
		gzip $FILE_PATH;	
	done;
	return 0;
}

# It can also return the path idgaf
# Params:
# $1 : path to the file in question
find_common_file_name_and_path() {
	echo $1 | rev | cut -d '.' -f2- | rev
}

# Gunzip'ing all the files save CPU
# No params.
degunzip_all_the_files() {
	for FILE in $(find $INPUT_DIR -type f -iname '*.gz'); do
		gunzip $FILE || return 1;
	done;
	return 0;
}

# Return the date suffix "YYYY-MM-DD"
# Params:
# $1 : Month or Day
# $2 : Day or Month
# Note: You can give them in any order, date doesn't care
compose_date_suffix() {
	echo $(date --date="$1 $2" +"%Y-%m-%d")
}

# Creates the folders before a given file path
# Params:
# $1 : File path
create_file_path() {
	# The easiest way to create all the directories before
	# a file without having to extract the file name is to
	# create the file as a directory, and removing it.
	# Parkour!
	mkdir -p $1 && rmdir $1
	return $?
}

# Would date barf up into stderr with the given params?
# I don't know, but this function does
# Params:
# $1 : Day or Month, doesn't matter
# $2 : Month or Day, doesn't matter
is_date_correct() {
	date --date="$1 $2" +"%Y-%m-%d" 2>/dev/null;
	return $?
}

# Grep over a specific file the given date in multiple formats
# and shove it into a neat little file
# Params:
# $1 : Path to the file
# $2 : Day or Month
# $3 : Month or Day
do_the_cat() {
	is_date_correct $3 $2 > /dev/null;
	# return if date cannot exist
	[ $? -ne 0 ] && return 1;
	DATE_SUFFIX=$(compose_date_suffix $3 $2);

	# Common syslog format : "May 08"
	DATA=$(grep "^$3 $2" $1)
	# Second common format, "2020-05-08"
	[ -z "$DATA" ] && DATA=$(cat $1 | grep "^$DATE_SUFFIX")
	# Syslog but without trailing 0s : "May  8"
	[ -z "$DATA" ] && DATA=$(cat $1 | grep "^$(date --date="$3 $2" +'%b %d' | sed 's/ 0/  /')")
	# Apache Access Log
	[ -z "$DATA" ] && DATA=$(grep "\[$(date --date="$3 $2" +'%d/%b/%Y'):" $1)
	# Apache Error Log
	[ -z "$DATA" ] && DATA=$(grep "\[$(date --date="$3 $2" +'%a %b %d')" $1)
	
	# If nothing was found, still, return
	# That often just means there were no logs that day
	[ ! -z "$DATA" ] || return 0;
	FILEPATH=$(printf "%s/%s-%s" $OUTPUT_DIR $(find_common_file_name_and_path $1) $(compose_date_suffix $3 $2));
	create_file_path $FILEPATH 2>/dev/null;
	# Add quotes or else echo chokes on its vomit
	echo "$DATA" >> $FILEPATH;
	#gzip $FILEPATH; TODO: Compress
	printf "%s" $(python3 -c "print('\u2713')")
	return 0;
}

# This just formats to extract the base file name
# Params:
# $1 : File path
show_file_end_name() {
	echo $1 | rev | cut -d '/' -f 1 | rev || return 1;
}

# Parse a file path for logs throughout the current year
# Params:
# $1 : File path
parse() {
	printf "%s:\t" $(show_file_end_name $1)
	for MONTH in $MONTHS; do
		printf "%s.. " $MONTH
		declare -i DAY;
		DAY=0;
		while (( $DAY < 31 )); do
			do_the_cat $1 $DAY $MONTH
			DAY=`expr $DAY+1`
		done;
	done;
	echo "";
	printf "Deleting %s\n" $1;
	rm $1;
	return 0;
}

main
