#!/bin/sh

# metgrid.sh
# 
#
# Created by ready on 29/09/2014.
# Copyright 2013,2014 __READY__. All rights reserved.

metgrid(){
local config_file="$1"
source $config_file
source $wrfmanager_functions

[[ -f $CARRYON ]] && exit
local metgridPath="$forecastPath/wps"

		
#cmd="time mpirun -np $NSLOTS $metgridPath/metgrid.exe"
cmd="time $metgridPath/metgrid.exe"
writeLogFile 0 "Running command $cmd"
$cmd		

#logfile="$metgridPath/metgrid.log"
#tail $logfile | while read line; do
#if echo "$line" | grep -q "Successful completion of program metgrid"; then
# do your stuff
if [[ $? -eq 0 ]]; then
	writeLogFile 0 "Task metgrid finished successfully"
else
	writeLogFile 2 "Task metgrid FAILED"
fi

rm -f $metgridPath/GRIBFILE.AA*
rm -f $metgridPath/PFILE*
#echo "`date` Error occured running metgrid.exe. metgrid aborted"
#exit -1
#fi
#done

}

config_file="$1" # configuration file
metgrid "$config_file"
