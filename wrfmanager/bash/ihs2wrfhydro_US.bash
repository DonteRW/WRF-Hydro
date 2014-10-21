#!/bin/bash
#
# This routine creates a csv file of the wrf-hydro output file for a specific organization.
# The ID hydro stations are converted to the station names.
# We also apply a threshold to the maximum discharges, specific to the organization.
#
# Author: Erick Fredj 
#
# created by ready on 21/09/14.
# Copyright 2014 __READY__. All rights reserved.

config_file=$1
input_file=$2
source $config_file

tail -n +2  ${org2wrfhydro} | sort -t"," -k3n,3 > sorted_org2wrfhydro.csv
nid=`sort -k4 $2 | awk '{print $4}' | uniq | wc -l`

echo "Station_Name,Station_Id,Time(sec),Date,Longitude(dec deg),Latitude(dec deg),Flowrate(cms), Head(m)"
counter=0
while [ $counter -lt $nid ]
do
if   [ "$counter" -ne 73 ]  && [ "$counter" -ne 97 ] && [ "$counter" -ne 101 ] &&  [ "$counter" -ne 165 ]
then
ihs_name=`cat sorted_org2wrfhydro.csv | awk -v hydro_id="$counter" 'BEGIN{FS=","}{if(hydro_id==$3) print $5}'`
bias=`cat sorted_org2wrfhydro.csv | awk -v hydro_id="$counter" 'BEGIN{FS=","}{if(hydro_id==$3) print $7}'`
cat $2 | awk -v ihs_name="$ihs_name" -v hydro_id="$counter"  -v bias="$bias" '{  if (hydro_id == $4) {d = ($7>bias)? "VERY HIGH": $7;  print ihs_name "," $4 "," $1"," $2"_" $3"," $5"," $6"," d "," $9; } }'
fi
counter=$(($counter+1))
done

rm sorted_org2wrfhydro.csv
