#!/bin/sh

# wrfmanager.sh
# DESCRIPTION: This is the main routine to perform periodic runs of  WRF-HYDRO.
# It calls sources the required config file, then calls other scripts for each stage of the simulation
#
# Author Erick Fredj
#
# Amended by Micha Silver
# Created by ready on 29/09/2014.
# Copyright 2014 __READY__. All rights reserved.

############################################
# Some preliminary checks
###########################################
if [[ $# -eq 0 ]]; then
	config_file=`pwd`/"wrfmanager.conf"
else
	config_file=$1
fi


if [[ ! -f $config_file ]] || [[ -z $config_file ]]; then
	echo "No configuration file found"
	echo "You need to prepare a configuraion file, such as wrfmanager.conf"
	echo "Exiting..."
	exit
fi

source $config_file
if [[ ! -d $WRF_log_path ]]; then
	echo "You need to set a Directory path for logging in $config_file."
	echo "Exiting..."
	exit
fi

# Be sure to remove stale file "CARRYON" from a previous failed run, in case it exists 
[[ -f $CARRYON ]] && rm -f $CARRYON

if [[ ! -f $wrfmanager_functions ]]; then
	echo "The set of wrfmanager functions: $wrfmanager_functions  not found. Aborting"
	exit
fi
source $wrfmanager_functions

# Check the validity of parameters in config file before starting the run
checkConfigParameters
if [[ "$retval" -gt 0 ]]; then
	writeLogFile 2 "Some config parameters did NOT verify."
	exit
fi

##################################################
# Now beginning simulation
##################################################
[[ -f $CARRYON ]] && exit
writeLogFile 0 "Beginning simulation run"
# Build the filesystem for the Operative WRF_HYDRO
${baseDir}/bash/wrf_filesystem_v2.0.6.sh "$config_file" 
pid=$!
wait $!
echo $?  # return status of $executable

# Prepare the namelist files
[[ -f $CARRYON ]] && exit
${baseDir}/bash/preprocess_v2.0.6.sh "$config_file" 
pid=$!
wait $!
echo $?  # return status of $executable

###########################
# WPS stages
###########################
[[ -f $CARRYON ]] && exit
cd $forecastPath/wps
writeLogFile 0 "Beginning geogrid"
# geogrid
${baseDir}/bash/geogrid_v2.0.6.sh "$config_file" >/dev/null &
pid=$!
wait $!
echo $?  # return status of $executable

# ungrid
[[ -f $CARRYON ]] && exit
writeLogFile 0 "Beginning ungrib"
${baseDir}/bash/ungrib-gfs0p5_v2.0.6.sh "$config_file" >/dev/null &
pid=$!
wait $!
echo $?  # return status of $executable

# metgrid
[[ -f $CARRYON ]] && exit
writeLogFile 0 "Beginning metgrid"
${baseDir}/bash/metgrid_v2.0.6.sh "$config_file" >/dev/null &
pid=$!
wait $!
echo $?  # return status of $executable


###########################
# WRF-HYDRO           
###########################
# Execution of Real unit (by default)
[[ -f $CARRYON ]] && exit
writeLogFile 0 "Beginning WRF-Hydro execution"
writeLogFile 0 "Execution on $NSLOTS nodes "
writeLogFile 0 "starting real.exe"
  
cd $forecastPath/wrf
ln -sf ./../wps/met_em.d* .
ln -sf ./../wps/geo_em.d* .

time mpirun -n $NSLOTS ./real.exe >/dev/null &
pid=$!
wait $!
echo $?  # return status of $executable
rm -f rsl.*
writeLogFile 0 "Execution of real unit completed"
writeLogFile 0 "Starting wrf.exe"
# Execution on all the reserved nodes of unit WRF
time mpirun -n $NSLOTS ./wrf.exe>/dev/null &
pid=$!
wait $!
echo $?  # return status of $executable
writeLogFile 0 "Execution of wrf.exe completed"

#############################
# POST processing
#############################
# [[ -f $CARRYON ]] && exit
# Prepare precip CSV files for creating animated maps
writeLogFile 0 "Starting post processing"
/usr/bin/python ${baseDir}/utilites/netcdf2text.py -i ${forecastPath}/wrf -o ${forecastPath}/post

# Prepare merged precipitation text file
preparePrecipFile

# Prepare pdf maps
cd ${forecastPath}/post 
ln -sf ${forecastPath}/wrf/wrfout_d03_* . 
# Precipitation plots 
${NCL_ROOT}/bin/ncl ${baseDir}/ncl/wrf_Precip_multi_files.ncl 

# MS: copy data to maps server in two steps to avoid processing a partial file on remote web server
copyToWeb

# Send data files by email
[[ -f $CARRYON ]] && exit
emailFrxstFile
emailPrecipFile

# Archive and delete old forecast
archiveForecasts

#############################
# END #
#############################

writeLogFile 0 "Forecast simulation run ended" 
