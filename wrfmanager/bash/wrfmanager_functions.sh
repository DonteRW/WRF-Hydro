#!/bin/bash

# wrfmanager_functions.sh
#
# Created by ready on 21/09/14.
# Copyright 2014 __READY__. All rights reserved.
# 
# Contains a set of functions called by the main daily_wrfmanager script

writeLogFile() {
# Updates the wrfmanager log file for each step of the procedure
# Takes two parameters:
# 	* First the log level as an integer - 0=INFO, 1=WARNING, 2=ERROR 
#	* Second is the string to enter into the log
case $1 in
	0)
	level="INFO"
	;;
	1)
	level="WARNING"
	;;
	2)
	level="ERROR"
	touch ${baseDir}/${CARRYON}
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

checkConfigParameters() {
# Verifies that all necessary parameters in the config file are available and reasonable values
	return_val=0
	if [[ -z "$baseDir" ]]; then
		writeLogFile 2 "You need to set your Base Directory" 
		return_val=1
	fi
	if [[ -z "$WRF_HYDRO_ROOT" ]]; then
		writeLogFile 2 "You need to set your WRF_HYDRO_ROOT Directory"
		return_val=2
	fi
	if [[ -z "$NCL_ROOT" ]]; then
		writeLogFile "You need to set your NCL_ROOT Directory"
		return_val=3
	fi

	case "Z${cc}" in
		Z00) writeLogFile 0 "Cycle runtime Z00" 
		    ;;
		Z06) writeLogFile 0 "Cycle runtime Z06"
		    ;;
		Z12) writeLogFile 0 "Cycle runtime Z12" 
		    ;;
		Z18) writeLogFile 0 "Cycle runtime Z18" 
		    ;;
		*) writeLogFile 2 "Invalid cycle runtime: ${cc} (Must be 00, 06, 12, 18)" 
		    return_val=4
		    ;;
	esac

	[[ -z $itimint ]] && itimint="6"               # time interval in (hours)
	[[ -z $forecast ]] && forecast="48"            # forecast in (hours)
	if [ $forecast -gt 336 ] ; then
		writeLogFile 2 "Invalid forecast period: $forecast. The forecast hour should be 0-336:" 
		return_val=5
	fi

	[[ -z $offsetdate ]] && offsetdate="00"        # offset date in (hours)
	if [ $offsetdate -gt 48 ] ; then
		writeLogFile 2 "Invalid offset date: $offsetdate. The offsetdate should be 00-48" 
		return_val=6
	fi

	[[ -z $NSLOTS ]] && NSLOTS=24
	[[ -z $USE_RESTART ]] && USE_RESTART="false"


	if [[ -z "$gis_hires" ]]; then
		writeLogFile 2 "The GIS high resolution hydro file Must be defined"
		return_val=8
	fi
	[[ -z $GWBASESWCRT ]] && GWBASESWCRT="0"

	# MS: Are the following two files cause for aborting? The model can finish without them...
	# Setting return_val to 0 to allow continuation
	if [[ -z "$org2wrfhydro" ]]; then
		writeLogFile 1 "The organization conversion file should be defined"
		return_val=0
	fi
	if [[ -z "$orgstations" ]]; then
		writeLogFile 1 "The organization stations file should be defined" 
		return_val=0
	fi

	# Log all important values
	writeLogFile 0 "GFS model cycle runtime: ${cc}"
	writeLogFile 0 "GFS time interval: ${itimint}" 
	writeLogFile 0 "Num. of processors: $NSLOTS" 
	writeLogFile 0 "Node that executes the work $HOSTNAME"
	writeLogFile 0 "Forecast started at ${TODAY} for ${forecast} hours with an offset of $offsetdate in (hours) from the download GFS data" 
	 
}

HYDROnamelistUpdate() {
# Creates the hydro.namelist file

	local config_file="$1"
	source $config_file
	source $wrfmanager_functions
	writeLogFile 0 Creating hydro.namelist

	# default parameters
	restartdate=`echo $restart_from_forecast_date | cut -b 1-10` # current date in yyyy-mm-dd format

	# set the forecast directory
	forecastPath=$baseDir/forecast/forecast_${cc}_${TODAY}

	# set the restart directory
	restartPath=$baseDir/forecast/forecast_${cc}_${restartdate}

	# set the restart date
	# add the forecast time in hours (LINUX)
	restart_from_date=$(date --d="$NOW +$offsetdate hours" "+%Y-%m-%d %H")

	restart_from_year=`echo $restart_from_date | cut -b 1-4`
	restart_from_mon=`echo $restart_from_date | cut -b 6-7`
	restart_from_day=`echo $restart_from_date | cut -b 9-10`
	restart_from_hour=`echo $restart_from_date | cut -b 12-13`

	# look for the restart directory and isrestart variable
	if [[ -d $restartPath  &&  $isrestart == ".true." ]]; then    
		comment=' ' 
		ln -sf ${restartPath}/wrf/HYDRO_RST.${restart_from_year}-${restart_from_mon}-${restart_from_day}_${restart_from_hour}_DOMAIN3 ${forecastPath}/wrf
	else
		comment='!'
	fi

	#add these lines out to the hydro.namelist file
	#==============================================
	cat>${forecastPath}/wrf/hydro.namelist << End_Of_HYDRO_Namelist_Input
&HYDRO_nlist

!!!! SYSTEM COUPLING !!!!
!Specify what is being coupled:  1=HRLDAS (offline Noah-LSM), 2=WRF, 3=NASA/LIS, 4=CLM
 sys_cpl = 2

!!!! MODEL INPUT DATA FILES !!!
!Specify land surface model gridded input data file...(e.g.: "geo_em.d03.nc")
 GEO_STATIC_FLNM = "geo_em.d03.nc"

!Specify the high-resolution routing terrain input data file...(e.g.: "Fulldom_hires_hydrofile.nc"
 GEO_FINEGRID_FLNM = "${gis_hires}"

!Specify the name of the restart file if starting from restart...comment out with '!' if not...
${comment} RESTART_FILE  = 'HYDRO_RST.${restart_from_year}-${restart_from_mon}-${restart_from_day}_${restart_from_hour}:00_DOMAIN3'

!!!! MODEL SETUP AND I/O CONTROL !!!!
!Specify the domain or nest number identifier...(integer)
 IGRID = 3

!Specify the restart file write frequency...(minutes)
 rst_dt = 1440   

!Specify the output file write frequency...(minutes)
 out_dt = 60 ! minutes

!Specify if output history files are to be written...(.TRUE. or .FALSE.)
 HISTORY_OUTPUT = .TRUE.

!Specify the number of output times to be contained within each output history file...(integer)
!   SET = 1 WHEN RUNNING CHANNEL ROUTING ONLY/CALIBRATION SIMS!!!
!   SET = 1 WHEN RUNNING COUPLED TO WRF!!!
 SPLIT_OUTPUT_COUNT = 1

! rst_typ = 1 : overwrite the soil variables from routing restart file.
 rst_typ = 0

!Restart switch to set restart accumulation variables = 0 (0-no reset, 1-yes reset to 0.0)
 RSTRT_SWC = 1

!Output high-resolution routing files...0=none, 1=total chan_inflow ASCII time-series, 2=hires grid and chan_inflow...
 HIRES_OUT = 2

!Specify the minimum stream order to output to netcdf point file...(integer)
!Note: lower value of stream order produces more output.
 order_to_write = 2

!!!! PHYSICS OPTIONS AND RELATED SETTINGS !!!!
!Switch for terrain adjustment of incoming solar radiation: 0=no, 1=yes
!Note: This option is not yet active in Verion 1.0...
!      WRF has this capability so be careful not to double apply the correction!!!
 TERADJ_SOLAR = 0

!Specify the number of soil layers (integer) and the depth of the bottom of each layer (meters)...
! Notes: In Version 1 of WRF-Hydro these must be the same as in the namelist.input file
!       Future versions will permit this to be different.
 NSOIL=4
 ZSOIL8(1) = -0.05
 ZSOIL8(2) = -0.25
 ZSOIL8(3) = -0.70 
 ZSOIL8(4) = -1.5 

!Specify the grid spacing of the terrain routing grid...(meters)
 DXRT = 100

!Specify the integer multiple between the land model grid and the terrain routing grid...(integer)
 AGGFACTRT = 30

!Specify the routing model timestep...(seconds)
 DTRT = 10

!Switch activate subsurface routing...(0=no, 1=yes)
 SUBRTSWCRT = 1

!Switch activate surface overland flow routing...(0=no, 1=yes)
 OVRTSWCRT = 1

!Switch to activate channel routing Routing Option: 1=Seepest Descent (D8) 2=CASC2D
 rt_option    = 1
 CHANRTSWCRT = 1

!Specify channel routing option: 1=Muskingam-reach, 2=Musk.-Cunge-reach, 3=Diff.Wave-gridded
 channel_option =3

!Specify the reach file for reach-based routing options...
 route_link_f = ""

!Switch to activate baseflow bucket model...(0=none, 1=exp. bucket, 2=pass-through)
GWBASESWCRT = ${GWBASESWCRT}

!Specify baseflow/bucket model initialization...(0=cold start from table, 1=restart file)
 GW_RESTART = 0

!Groundwater/baseflow mask specified on land surface model grid...
!Note: Only required if baseflow bucket model is active
gwbasmskfil = ${gwbasmskfil}

/
End_Of_HYDRO_Namelist_Input
	writeLogFile 0 hydro.namelist completed
}

namelistUpdate(){
# Writes out the two namelist files for wps and wrf
# namelist.wps and namelist.input

	local config_file="$1"
	source $config_file
	source $wrfmanager_functions

	writeLogFile 0 Creating namelist.wps
	# local parameters
	restartdate=`echo $restart_from_forecast_date | cut -b 1-10` # current date in yyyy-mm-dd format

	# default parameters
	# set the forecast directory
	forecastPath=$baseDir/forecast/forecast_${cc}_${TODAY}
	wrfForecastPath=$forecastPath/wrf
	wpsForecastPath=$forecastPath/wps

	# set the restart directory
	restartPath=$baseDir/forecast/forecast_${cc}_${restartdate}

	# wps time
	wps_start_year=$(date  --d="$CURDATE" "+%Y")
	wps_start_mon=$(date  --d="$CURDATE" "+%m")
	wps_start_day=$(date  --d="$CURDATE" "+%d")
	wps_start_hour=${cc}

	# add the forecast time in hours (LINUX)
	local HH=$(date  --d="$CURDATE" "+%H")
	wps_inc_forecast=$(($forecast+48+$wps_start_hour-$HH))
	wps_endDate=$(date --d="$CURDATE +$wps_inc_forecast hours" "+%Y-%m-%d %H")
		
	wps_end_year=`echo $wps_endDate | cut -b 1-4`
	wps_end_mon=`echo $wps_endDate | cut -b 6-7`
	wps_end_day=`echo $wps_endDate | cut -b 9-10`
	wps_end_hour=`echo $wps_endDate | cut -b 12-13`

	#add these lines out to the namelist.wps file
	#============================================
	cat>$wpsForecastPath/namelist.wps << EndOfNamelistWps  
	&share
 wrf_core = 'ARW',
 max_dom = 3,
start_date='${wps_start_year}-${wps_start_mon}-${wps_start_day}_${wps_start_hour}:00:00','${wps_start_year}-${wps_start_mon}-${wps_start_day}_${wps_start_hour}:00:00','${wps_start_year}-${wps_start_mon}-${wps_start_day}_${wps_start_hour}:00:00'
end_date='${wps_end_year}-${wps_end_mon}-${wps_end_day}_${wps_end_hour}:00:00','${wps_end_year}-${wps_end_mon}-${wps_end_day}_${wps_end_hour}:00:00','${wps_end_year}-${wps_end_mon}-${wps_end_day}_${wps_end_hour}:00:00'
 interval_seconds = 3600,
 io_form_geogrid = 2,
/
&geogrid
 parent_id         =   0,   1, 2,
 parent_grid_ratio =   1,   3, 3,
 i_parent_start    =   1,  47, 69,
 j_parent_start    =   1,  42, 50,
 e_we              =  140, 187,121,
 e_sn              =  140, 184,223,
 geog_data_res     = '2m','30s','30s'
 dx = 27000,
 dy = 27000,
 map_proj = 'lambert',
 ref_lat   =  32.00,
 ref_lon   = 33.49,
 truelat1  =  33.5,
 truelat2  =  29.5,
 stand_lon =  33.49,
geog_data_path = "${WRF_HYDRO_ROOT}/WPS_GEOG/geog"
opt_geogrid_tbl_path="${WRF_HYDRO_ROOT}/WPS/geogrid"
/

&ungrib
 out_format = 'WPS',
 prefix = 'FILE'
/

&metgrid
 fg_name = 'FILE',
 opt_metgrid_tbl_path="${WRF_HYDRO_ROOT}/WPS/metgrid"
 io_form_metgrid = 2,
/
EndOfNamelistWps
	
	writeLogFile 0 namelist.wps completed
	writeLogFile 0 Creating namelist.input

	# add the forecast time in hours (LINUX)
	initDate=$(date --d="$CURDATE +$offsetdate hours" "+%Y-%m-%d %H")

	start_year=`echo $initDate | cut -b 1-4`
	start_mon=`echo $initDate | cut -b 6-7`
	start_day=`echo $initDate | cut -b 9-10`
	start_hour=`echo $initDate | cut -b 12-13`

	# add the forecast time in hours (LINUX)
	endDate=`date -d "$initDate $forecast hours" +"%Y-%m-%d %H"`

	end_year=`echo $endDate | cut -b 1-4`
	end_mon=`echo $endDate | cut -b 6-7`
	end_day=`echo $endDate | cut -b 9-10`
	end_hour=`echo $endDate | cut -b 12-13`

	# look for the restart directory
	if [[ -d $restartPath  &&  $isrestart == '.true.' ]]; then
		ln -sf  $restartPath/wrf/wrfrst_d0?_${start_year}-${start_mon}-${start_day}_${start_hour}* $wrfForecastPath
	fi

	# namelist.input new time section
		
	cat>$wrfForecastPath/namelist.input << End_Of_Namelist_Input 
&time_control
run_days                            = 0,
run_hours                           = ${forecast},
 run_minutes                         = 0,
 run_seconds                         = 0,
start_year                          = ${start_year},${start_year},${start_year},
start_month                         = ${start_mon},${start_mon},${start_mon},
start_day                           = ${start_day},${start_day},${start_day},
start_hour                          = ${start_hour},${start_hour},${start_hour},
start_minute                        = 00,00,00,
start_second                        = 00,00,00,
end_year                            = ${end_year},${end_year},${end_year},
end_month                           = ${end_mon},${end_mon},${end_mon},
end_day                             = ${end_day},${end_day},${end_day},
end_hour                            = ${end_hour},${end_hour},${end_hour},
end_minute                          = 00,00,00,
end_second                          = 00,00,00,
interval_seconds                    = 21600
input_from_file                     = .true.,.true.,.true.,
history_interval                    = 360, 180, 60,
frames_per_outfile                  = 1, 1, 1,
restart                             = ${isrestart},
restart_interval                    = 1440,
io_form_history                     = 2
io_form_restart                     = 2
io_form_input                       = 2
io_form_boundary                    = 2
debug_level                         = 0
/

 &domains
 time_step                           = 135,
 time_step_fract_num                 = 0,
 time_step_fract_den                 = 1,
 max_dom                             = 3,
 e_we                                =  140, 187,121,
 e_sn                                =  140, 184,223,
 e_vert                              = 30,    30,    30
 p_top_requested                     = 5000,
 num_metgrid_levels                  = 27,
 num_metgrid_soil_levels             = 4,
 dx                                  = 27000, 9000,  3000
 dy                                  = 27000, 9000,  3000
 grid_id                             = 1,     2,     3 
 parent_id                           = 0,     1,     2
 i_parent_start                      = 1,  47, 69, 
 j_parent_start                      = 1,  42, 50,
 parent_grid_ratio                   = 1,     3,     3
 parent_time_step_ratio              = 1,     3,     3
 feedback                            = 0,
 smooth_option                       = 0
 /

 &physics
 mp_physics                          = 6,     6,     6,   6,
 ra_lw_physics                       = 1,     1,     1,   1,
 ra_sw_physics                       = 1,     1,     1,   1,
 radt                                = 30,    30,    30, 30,
 sf_sfclay_physics                   = 2,     2,     2,   2,
 sf_surface_physics                  = 2,     2,     2,   2,
 bl_pbl_physics                      = 2,     2,     2,   2, 
 bldt                                = 0,     0,     0,   0,
 cu_physics                          = 1,     1,     1,   1,
 cudt                                = 5,     5,     5,   5,
 isfflx                              = 1,
 ifsnow                              = 0,
 icloud                              = 1,
 surface_input_source                = 1,
 swrad_scat                          = 1.
 num_land_cat                        = 24,
 num_soil_layers                     = 4,
 sf_urban_physics                    = 0,     0,     0,   0,
 mp_zero_out                         = 0,
 mp_zero_out_thresh                  = 1.e-8
 no_mp_heating                       = 0
 sst_update                          = 0,
 usemonalb                           = .false.,
 rdmaxalb                            = .true.

 /

 &fdda
 grid_fdda                           = 1, 0, 0, 0,
 gfdda_inname                        = 'wrffdda_d<domain>'
 gfdda_interval_m                    = 360, 0, 0, 0,
 gfdda_end_h                         = 144, 0, 0, 0,
 io_form_gfdda                       = 2
 fgdt                                = 0, 0, 0, 0,
 if_no_pbl_nudging_uv                = 0, 0, 0, 0,
 if_no_pbl_nudging_t                 = 1, 1, 1, 1,
 if_no_pbl_nudging_q                 = 1, 1, 1, 1,
 if_zfac_uv                          = 0, 0, 0, 0,
  k_zfac_uv                          = 10, 10, 10, 10,
 if_zfac_t                           = 1, 0, 0, 0,
  k_zfac_t                           = 10, 10, 10, 10,
 if_zfac_q                           = 1, 0, 0, 0,
  k_zfac_q                           = 10, 10, 10, 10,
 guv                                 = 0.0003, 0.0003, 0.0003, 0.0003,
 gt                                  = 0.0003, 0.0003, 0.0003, 0.0003,
 gq                                  = 0.0003, 0.0003, 0.0003, 0.0003,
 if_ramping                          = 0
 dtramp_min                          = 0.0
 grid_sfdda                          = 0, 0, 0
 sgfdda_inname                       = 'wrfsfdda_d<domain>'
 sgfdda_end_h                        = 6, 6, 6, 6,
 sgfdda_interval_m                   = 180, 180, 180, 180,
 io_form_sgfdda                      = 2
 guv_sfc                             = 0.0003, 0.0003, 0.0003, 0.0003,
 gt_sfc                              = 0.0003, 0.0003, 0.0003, 0.0003,
 gq_sfc                              = 0.0003, 0.0003, 0.0003, 0.0003,
 rinblw                              = 250.0
/

 &dynamics
 rk_ord                              = 3,
 w_damping                           = 1,
 diff_opt                            = 1,
 km_opt                              = 4,
 diff_6th_opt                        = 0,      0,      0,      0,
 diff_6th_factor                     = 0.12,   0.12,   0.12,  0.12,
 base_temp                           = 290.
 damp_opt                            = 1,
 zdamp                               = 5000.,  5000.,  5000.,  5000.0,
 dampcoef                            = 0.01,    0.01,    0.01,  0.01,
 khdif                               = 0,      0,      0,    0,
 kvdif                               = 0,      0,      0,    0,
 smdiv                               = 0.1,    0.1,    0.1,    0.1, 
 emdiv                               = 0.01,   0.01,   0.01,   0.01,
 epssm                               = 0.1, 0.1, 0.1, 0.2,
 non_hydrostatic                     = .true., .true., .true.,.true.,
 mix_isotropic                       = 0,      0,      0,      0,
 mix_upper_bound                     = 0.1     0.1,    0.1,    0.1,
 h_mom_adv_order                     = 5,      5,      5,      5,
 v_mom_adv_order                     = 3,      3,      3,      3,
 h_sca_adv_order                     = 5,      5,      5,      5,
 v_sca_adv_order                     = 3,      3,      3,      3,
 moist_adv_opt                       = 1,      1,      1,      1,
 scalar_adv_opt                      = 1,      1,      1,      1,
 time_step_sound                     = 0,      0,      0,      0,

 /

 &bdy_control
 spec_bdy_width                      = 5,
 spec_zone                           = 1,
 relax_zone                          = 4,
 specified                           = .true., .false.,.false.,.false.,
 nested                              = .false., .true., .true.,.true.,
 /

 &grib2
 /

 &namelist_quilt
 nio_tasks_per_group = 0,
 nio_groups = 1,
 /
End_Of_Namelist_Input
	writeLogFile 0 namelist.input completed	
}

emailFrxstFile()  {
	local config_file="$1"
	source $config_file
	source $wrfmanager_functions
# Sends an email message to pre-configured recipients 
# with the frxst_out_pts.txt file as attachment

	if [[ ! $send_frxst == "true" ]]; then
		writeLogFile 1 "In config file email is cancelled. NO frxst email sent"
		exit
	else
	# Prepare frxst csv file with extreme results removed
		cp $forecastPath/wrf/frxst_pts_out.txt  $forecastPath/wrf/tmp_frxst_pts_out.txt
		${baseDir}/bash/ihs2wrfhydro_US.bash ${config_file} $forecastPath/wrf/tmp_frxst_pts_out.txt >$forecastPath/wrf/forecast_${cc}_${TODAY}_frxst_pts_out.txt

		rm ${forecastPath}/wrf/tmp_frxst_pts_out.txt
	# Calulate total runtime to add to the message
		STARTSECS=`date --date="$start_of_run" +%s`
		CURSECS=`date +%s`
		DIFFHRS=$(( ($CURSECS-$STARTSECS)/3600 ))
		DIFFMINS=$(( (($CURSECS-$STARTSECS)%3600)/60 ))
		TTLRUNTIME=`printf "%02d:%02d" $DIFFHRS $DIFFMINS`
		ENDTIME=`date +"%d-%m-%Y %H:%M"`

	# Construct the message
		cat > forecast_msg.txt << EOF
Hello Amir:
Attached is the new forecast data file for Init date: ${TODAY}

Simulation summary:
-------------------
	Run on server:  $HOSTNAME
	For             $TTLRUNTIME hours
	Using           $NSLOTS processors
	Completed at    $ENDTIME

--
Erick
EOF

		mutt -s "Daily forecast report" \
			-a $forecastPath/wrf/forecast_${cc}_${TODAY}_frxst_pts_out.txt \
			-c $email_frxst+cc \
			--  $email_frxst_to \
			< forecast_msg.txt

		if [[ $? -eq 0 ]]; then
			writeLogFile 0 "Frxst file send by email"
		else
			writeLogFile 1 "Frxst email FAILED"
		fi
	fi
}


copyToWeb() {

		local config_file="$1"
	    source $config_file
	    source $wrfmanager_functions

		# Create all remote directories on web server
		# Upload the text files to the correct remote dirs

		# setup remote server directories
		remoteOK=true
		SSH_CMD="/usr/bin/ssh -p 10022"
		WEB_USER="ihs@maps.arava.co.il"
		SCP_CMD="/usr/bin/scp -P 10022"
		$SSH_CMD $WEB_USER "mkdir -p /home/ihs/WRF_Data/forecast_${cc}_${TODAY}"
		if [[ $? -ne 0 ]]; then
			remoteOK=false
		fi
		$SSH_CMD $WEB_USER "mkdir -p /home/ihs/WRF_Maps/precip_csv_${cc}_${TODAY}"
		if [[ $? -ne 0 ]]; then
			remoteOK=false
		fi
		$SSH_CMD $WEB_USER "mkdir -p /home/ihs/WRF_Rain/rain_${cc}_${TODAY}"
		if [[ $? -ne 0 ]]; then
			remoteOK=false
		fi
		if [[ $remoteOK == "true" ]]; then
        	writeLogFile 0 "Remote directories created on web server"
		else
        	writeLogFile 1 "Remote directories on web server FAILED"
		fi

		# MS: copy data to maps server in two steps to avoid processing a partial file on remote web server 
		# frxst_pts_out

		$SCP_CMD ${forecastPath}/wrf/frxst_pts_out.txt ${WEB_USER}:/home/ihs/WRF_Data/forecast_${cc}_${TODAY}/.frxst.part 
		$SSH_CMD $WEB_SRV mv /home/ihs/WRF_Data/forecast_${cc}_${TODAY}/.frxst.part /home/ihs/WRF_Data/forecast_${cc}_${TODAY}/frxst_pts_out.txt  
		if [[ $? == 0 ]]; then
        	writeLogFile 0 "frxst data transferred successfully"
		else
        	writeLogFile 1 "frxst data transfer FAILED"
		fi

		# precip csv files (tar archive)
		$SCP_CMD ${forecastPath}/post/precip_csv.tar.gz ${WEB_USER}:/home/ihs/WRF_Maps/precip_csv_${cc}_${TODAY}/.csv.part 
		$SSH_CMD $WEB_SRV mv /home/ihs/WRF_Maps/precip_csv_${cc}_${TODAY}/.csv.part /home/ihs/WRF_Maps/precip_csv_${cc}_${TODAY}/precip_csv.tar.gz  

		if [[ $? == 0 ]]; then
        	writeLogFile 0 "Precip CSV data transferred successfully"
		else
        	writeLogFile 1 "Precip CSV data transfer FAILED"
		fi

		# rainfall text files 
		$SCP_CMD ${forecastPath}/post/wrfout_precip_allstn.txt ${WEB_USER}:/home/ihs/WRF_Rain/rain_${cc}_${TODAY}/.precip.part 
		$SSH_CMD $WEB_SRV mv /home/ihs/WRF_Rain/rain_${cc}_${TODAY}/.precip.part /home/ihs/WRF_Rain/rain_${cc}_${TODAY}/wrfout_precip_allstn.txt  

		if [[ $? == 0 ]]; then
        	writeLogFile 0 "Rainfall text file transferred successfully"
		else
        	writeLogFile 1 "Rainfall text transfer FAILED"
		fi
}


preparePrecipFile() {
		local config_file="$1"
	    source $config_file
		source $wrfmanager_functions
# Call ncl script to build merged precipitation file
# Prepare precipitation Report
	writeLogFile 0 "Preparing precipitation files"
    /usr/bin/ncrcat ${forecastPath}/post/wrfout_d03_* $forecastPath/post/wrfout_d03_${TODAY}_merge.nc


    $NCARG_ROOT/bin/ncl ${forecastPath}/post/wrfout_to_station_precip.ncl \
    configFile='"'${orgstations}'"' \
    input_file='"'${forecastPath}/post/wrfout_d03_${TODAY}_merge.nc'"' \
    output_prefix='"'${forecastPath}/post'"' 1>/dev/null 2>&1

    /bin/mv ${forecastPath}/post/tmp_wrfout_precip_allstn_d03.txt ${forecastPath}/post/wrfout_precip_allstn.txt
	if [[ $? -eq 0 ]]; then
		writeLogFile 0 "Precipitation text file prepared"
	else
		writeLogFile 1 "Preparation of precipitation file FAILED"
	fi

# Call python script to add accumulated precipitation
	cmd="python ${baseDir}/utilities/precip2accum.py -i ${forecastPath}/post/wrfout_precip_allstn.txt"
	writeLogFile 0 "Running $cmd"
	$cmd
	if [[ $? -eq 0 ]]; then
		writeLogFile 0 "Accumulated precipitation values added"
	else
		writeLogFile 1 "Accumulated preparation script FAILED"
	fi
}


emailPrecipFile()  {

		local config_file="$1"
	    source $config_file
		source $wrfmanager_functions
		# Sends an email message to pre-configured recipients 
# with the precipitation data file as attachment

	if [[ ! $send_precip == "true" ]]; then
		writeLogFile 1 "In config file email is cancelled. NO precipitation email sent"
		exit
	else
	# Construct the message
		cat > precip_msg.txt << EOF
Hello Amir:
Attached is the new precipitation data file for Init date: ${TODAY}
--
Erick
EOF

		mutt -s "Daily precipitation report" \
			-a $forecastPath/post/wrfout_precip_allstn.txt \
			-c $email_precip_cc \
			--  $email_precip_to \
			< precip_msg.txt

		if [[ $? -eq 0 ]]; then
			writeLogFile 0 "Precip file send by email"
		else
			writeLogFile 1 "Precip email FAILED"
		fi
	fi
}

archiveForecasts() {
	local config_file="$1"
    source $config_file
	source $wrfmanager_functions

	writeLogFile 0 "Archviing and deleting old forecasts"

	if [[ $delete_old_forecasts == 'true' ]]; then
		for f in `find $forecastRoot -type d -mtime +${delete_old_forecasts_age} `; do
			writeLogFile 1 "Permanently deleting $f"
			rm -rf $f
		done
	
	else
		writeLogFile 1 "Deleting disabled in config. Nothing deleted"
	fi

	df_msg=`df | grep "home"`
	writeLogFile 1 "Current Disk Space: $df_msg"
	
	# send warning email if disk use > 60%
	du=`df | grep home | awk '{print $4}' | sed -i 's/\%//'`
	if [[ $du -gt 60 ]]; then
	# Construct the message
		cat > diskuse_msg.txt << EOF
Hello Erick:
Disk use in /home directory for: ${TODAY}
$df_mag
--

EOF
        mutt -s "Disk use report" ${email_diskuse_to} < diskuse_msg.txt
	fi
	writeLogFile 0 Archiving completed

}
