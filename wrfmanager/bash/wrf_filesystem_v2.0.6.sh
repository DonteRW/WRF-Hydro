#!/bin/sh

# wrf_filesystem_v2.0.6.sh
# DESCRIPTION: This routine file system (or filesystem) is used to control 
# how information is stored and retrieved in the Operational WRF_HYDRO.
#
# Author Erick Fredj
#
# Amended by Micha Silver
# Created by ready on 28/09/2014.
# Copyright 2014 __READY__. All rights reserved.


config_file=$1
source $config_file
source $wrfmanager_functions
writeLogFile 0 "Building the WRF-HYDRO filesystem tree"
[[ -f $CARRYON ]] && exit
#

# base directories
cshScriptPath=$baseDir/csh
awkScriptPath=$baseDir/awk
datScriptPath=$baseDir/dat
nclScriptPath=$baseDir/ncl

# look for the restart directory
restartPath=$baseDir/forecast/forecast_${cc}_${restart_from_forecast_date}

echo cshScriptPath: $cshScriptPath 
echo awkScriptPath: $awkScriptPath 
echo datScriptPath: $datScriptPath 
echo nclScriptPath: $nclScriptPath

if [[ -d $restartPath ]]; then    
	writeLogFile 0 "Restart Path: $restartPath"
else
	writeLogFile 1 "No Restart Path found" 
fi

# set the subdirectories
# gfs
gfsDataPath=$forecastPath/gfs0p5
# wps
wpsForecastPath=$forecastPath/wps
# wrf
wrfForecastPath=$forecastPath/wrf
wrfRestartPath=$restartPath/wrf
# post
postForecastPath=$forecastPath/post

# set environmental platform
mkdir -p $gfsDataPath 
mkdir -p $wpsForecastPath 
mkdir -p $wrfForecastPath
mkdir -p $postForecastPath

###############################################################################
########## Create soft links
cd $wrfForecastPath

writeLogFile 0 "Creating softlinks from: $baseDir"
# IHS stations names
ln -sf ${org2wrfhydro} .

# WRF_HYDRO parameters
ln -sf $baseDir/run/aerosol_lat.formatted .
ln -sf $baseDir/run/aerosol_lon.formatted .
ln -sf $baseDir/run/aerosol_plev.formatted .
ln -sf $baseDir/run/aerosol.formatted .
ln -sf $baseDir/run/CAM_ABS_DATA .
ln -sf $baseDir/run/CAM_AEROPT_DATA .
ln -sf $baseDir/run/CAMtr_volume_mixing_ratio .
ln -sf $baseDir/run/CAMtr_volume_mixing_ratio.A1B .
ln -sf $baseDir/run/CAMtr_volume_mixing_ratio.A2 .
ln -sf $baseDir/run/CAMtr_volume_mixing_ratio.RCP4.5 .
ln -sf $baseDir/run/CAMtr_volume_mixing_ratio.RCP6 .
ln -sf $baseDir/run/CAMtr_volume_mixing_ratio.RCP8.5 .
ln -sf $baseDir/run/CLM_ALB_ICE_DFS_DATA .
ln -sf $baseDir/run/CLM_ALB_ICE_DRC_DATA .
ln -sf $baseDir/run/CLM_ASM_ICE_DFS_DATA .
ln -sf $baseDir/run/CLM_ASM_ICE_DRC_DATA .
ln -sf $baseDir/run/CLM_DRDSDT0_DATA .
ln -sf $baseDir/run/CLM_EXT_ICE_DFS_DATA .
ln -sf $baseDir/run/CLM_EXT_ICE_DRC_DATA .
ln -sf $baseDir/run/CLM_KAPPA_DATA .
ln -sf $baseDir/run/CLM_TAU_DATA .
ln -sf $baseDir/run/ETAMPNEW_DATA .
ln -sf $baseDir/run/ETAMPNEW_DATA.expanded_rain .
ln -sf $baseDir/run/grib2map.tbl .
ln -sf $baseDir/run/gribmap.txt .
ln -sf $baseDir/run/ozone_lat.formatted .
ln -sf $baseDir/run/ozone_plev.formatted .
ln -sf $baseDir/run/ozone.formatted .
ln -sf $baseDir/run/RRTM_DATA .
ln -sf $baseDir/run/RRTMG_LW_DATA .
ln -sf $baseDir/run/RRTMG_SW_DATA .
ln -sf $baseDir/run/SOILPARM.TBL .
ln -sf $baseDir/run/tr49t67 .
ln -sf $baseDir/run/tr49t85 .
ln -sf $baseDir/run/tr67t85 .

ln -sf $baseDir/run/GENPARM.TBL .
ln -sf $baseDir/run/LANDUSE.TBL .
ln -sf $baseDir/run/MPTABLE.TBL .
ln -sf $baseDir/run/URBPARM.TBL .
ln -sf $baseDir/run/VEGPARM.TBL .
ln -sf $baseDir/run/CHANPARM.TBL .
ln -sf $baseDir/run/DISTR_HYDRO_CAL_PARMS.TBL .
ln -sf $baseDir/run/GWBUCKPARM.TBL .
ln -sf $baseDir/run/HYDRO.TBL .
ln -sf $baseDir/run/LAKEPARM.TBL .
ln -sf $baseDir/run/URBPARM_UZE.TBL .

writeLogFile 0 "Creating additional softlinks from: $WRF_HYDRO_ROOT"
# GIS
ln -sf ${gis_hires} .

# WRF executables
ln -sf $WRF_HYDRO_ROOT/WRFV3/main/wrf.exe .
ln -sf $WRF_HYDRO_ROOT/WRFV3/main/real.exe .
ln -sf $WRF_HYDRO_ROOT/WRFV3/main/nup.exe .
ln -sf $WRF_HYDRO_ROOT/WRFV3/main/ndown.exe .

########################################################
cd $postForecastPath

# NCL scripts
ln -sf $baseDir/ncl/wrfout_to_station_precip.ncl .

# IHS csv
ln -sf ${orgstations} .
ln -sf ${org2wrfhydro} .

# BASH scripts
ln -sf $baseDir/bash/ihs2wrfhydro_US.bash .

########################################################
cd $wpsForecastPath

# WPS executables

ln -sf $WRF_HYDRO_ROOT/WPS/geogrid.exe .
ln -sf $WRF_HYDRO_ROOT/WPS/ungrib.exe .
ln -sf $WRF_HYDRO_ROOT/WPS/metgrid.exe .

ln -sf $WRF_HYDRO_ROOT/WPS/link_grib.csh .
ln -sf $WRF_HYDRO_ROOT/WPS/ungrib/Variable_Tables/Vtable.GFS Vtable

writeLogFile 0 "WRF-HYDRO Filesystem is ready"

