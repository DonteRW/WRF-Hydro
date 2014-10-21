#!/bin/bash

# ungrib.sh
# 
#
# Created by ready on 9/2/13.
# Copyright 2013 __READY__. All rights reserved.

ungrib(){

local config_file="$1"
source $config_file
source $wrfmanager_functions

[[ -f $CARRYON ]] && exit 
local ungribPath="$forecastPath/wps"
local gfsDataPath="$forecastPath/gfs0p5"
	
writeLogFile 0 "Task ungrib started"
	
# link_grib.csh running
cmd="/bin/csh $ungribPath/link_grib.csh $gfsDataPath/gfs.t*"
writeLogFile 0 "Running command $cmd"
$cmd

if [[ $? -eq 0 ]]; then
	writeLogFile 0 "Command $cmd completed successfully"
else
	writeLogFile 2 "Command $cms FAILED"
fi

# ungrib.exe running
#cmd="time mpirun -np $NSLOTS $ungribPath/ungrib.exe"
cmd="time $ungribPath/ungrib.exe"
writeLogFile 0 "Running command $cmd"
$cmd
if [[ $? -eq 0 ]]; then
        writeLogFile 0 "Command $cmd completed successfully"
else
        writeLogFile 2 "Command $cms FAILED"
fi

#echo "`date` Task ungrib finished"
	
}

config_file="$1" # configuration file
ungrib "$config_file"
