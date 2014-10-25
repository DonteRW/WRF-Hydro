#!/bin/bash

# Get the cycle from command line (just for this test)
export cc=$1
###################################################################
###### All the below should be in the wrfmanager_Z* config files ###
export GFS_DATE=`date -u "+%Y%m%d"`  # current date in UTC time zone
export GFS_DATE_STR=${GFS_DATE}${cc}
export GFS_REMOTE_DIR="gfs.${GFS_DATE_STR}"
export GFS_URL="http://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod/"
# prepare list of 6 hr intervals for GFS files
export GFS_INTERVALS=`seq --equal-width --separator=" " 0 6 96`
export GFS_FILE_PREFIX="gfs.t"
export GFS_FILE_MIDDLE="z.pgrb2f"
export WGET="`which wget` --no-check-certificate --quiet"
# THese vars for testing
export forecastPath="./test" 
export WRF_log_file=$forecastPath/wrf_$GFS_DATE.log
export CARRYON=$forecastPath/.carryon
export GFS_LOCAL_DIR=${forecastPath}/gfs0p5
###################################################################

# source the function 
source wget_function.sh

# Remove stale CARRYON file
[[ -f $CARRYON ]] && rm -f $CARRYON

#Prepare output dir
mkdir -p $GFS_LOCAL_DIR

# run the function
wgetGFSFiles

