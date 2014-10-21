#!/bin/bash

# preprocess_v2.0.6.sh
# 
# Calls functions to create the required namelist files
# Calls a csh function to download all needed GFS file
# Created by ready on 21/09/14.
# Copyright 2014 __READY__. All rights reserved.

config_file="$1"
source $config_file
source $wrfmanager_functions

# base directories
cshScriptPath=$baseDir/csh
awkScriptPath=$baseDir/awk
gfsDataPath=$baseDir/forecast/forecast_${cc}_${TODAY}/gfs0p5

# download GFS files from Z$shour
writeLogFile 0 Beginning download of GFS files
# MS changed tm_today to match UTC date for GFS files
#tmp_today=$(date --date="$TODAY" "+%Y%m%d%H")
tmp_today=$(date -u "+%Y%m%d%H")
writeLogFile 0 Requesting GFS files for $tmp_today 
tmp_forecast=$(echo "$forecast+48" | bc)
csh ${cshScriptPath}/wget_gfs-0p5.csh "${tmp_today}" "${itimint}" "${tmp_forecast}" "${cc}" "${gfsDataPath}" "${awkScriptPath}" "${cshScriptPath}"
writeLogFile 0 Download of GFS file completed

# Update namelist.wps (WPS) preprocessing and namelist.input (WRF) model
namelistUpdate "$config_file"

#Update hydro.namelist (WRF-HYDRO) model
HYDROnamelistUpdate "$config_file"

writeLogFile 0 Preprocessing completed
