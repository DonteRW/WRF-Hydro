#!/bin/sh

# geogrid.sh
# 
#
# Created by ready on 29/09/14.
# Copyright 2013 __READY__. All rights reserved.

geogrid(){	
config_file=$1 # configuration file
source $config_file
source $wrfmanager_functions

[[ -f $CARRYON ]] && exit
local geogridPath=$forecastPath/wps

#cmd="time mpirun -np $NSLOTS $geogridPath/geogrid.exe"
cmd="time $geogridPath/geogrid.exe"		
writeLogFile 0 "Running command $cmd"
$cmd
		
if [[ $? -eq 0 ]]; then
	writeLogFile 0 "Geogrid command: $cmd completed successfully"
else
	writeLogFile 2 "Geogrid command: $cmd  FAILED"
fi

logfile="$geogridPath/geogrid.log"
				
tail -1 $logfile | while read line; do
#    echo "$line" | grep -c 'Successful completion of program geogrid'
if echo "$line" | grep -q 'Successful completion of program geogrid'; then
	# do your stuff
	echo "`date` Task geogrid finished"
else
	echo "`date` Error occured running geogrid.exe. geogrid aborted"
fi
done		
}

config_file=$1 # configuration file
geogrid "$config_file"
