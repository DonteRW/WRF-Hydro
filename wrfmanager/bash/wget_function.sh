#!/bin/bash

# Copy of the writeLogFile function
function writeLogFile() {
	case $1 in
		0)
		level="INFO"
		;;
		1)
		level="WARNING"
		;;
		2)
		level="ERROR"
		touch ${CARRYON}
		;;
		*)
		level=""
	esac

	comment=${*:2}
	if [[ -f $CARRYON ]]; then
		comment="${comment}, Aborting..."
	fi
	prog=`basename $0`
	echo $(date):$level:$prog:$comment >> $WRF_log_file
}


function wgetGFSFiles() {
[[ -f $CARRYON ]] && exit
# Loop thru all the GFS intervals
for i in $GFS_INTERVALS; do \
	GFS_FILE=${GFS_FILE_PREFIX}${cc}${GFS_FILE_MIDDLE}${i}
	GFS_FULL_URL=${GFS_URL}${GFS_REMOTE_DIR}/${GFS_FILE}
	writeLogFile 0 Beginning download of $GFS_FULL_URL
	$WGET $GFS_FULL_URL --output-document=$GFS_LOCAL_DIR/$GFS_FILE
	if [[ $? -eq 0 ]]; then
		writeLogFile 0 Download of $GFS_FILE completed
	else
		writeLogFile 2 Download of $GFS_FILE FAILED
	fi
done
}

export -f wgetGFSFiles
export -f writeLogFile
