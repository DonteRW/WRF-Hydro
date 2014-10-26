#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Author:   Micha Silver
Version:  0.3
Description:  
    This routine reads a CSV file of flow rates for each of the hydrometer stations
    with hourly data for a period of 24 hours.
    All discharge values are entered into an array for each hydrostation
    The array of discharge values is used build a hydrometric graph for each station
    Graphs are output to png files, one for each station

Options:
    Command line takes only one option: the directory containing hydrographs.conf (the config file)
    all other configurations are in that file

Updates:
    20140920 - changed update_maxflows routine to use station_num instead of id
    20141025 - moved the functions to a speparate file
	       implemented a generic copying and archiving function
"""

import os, sys, ConfigParser, logging
import hg_functions as hg

def main():
    """
    Loops thru a number of index values,retrieved from a db query, reads rows 
    from the csv file passed on the command line
    Each row contains data for a certain station at a certain time
    The loop aggregates the data, and creates a discharge array for each station
    This array is fed to a function to create a hydrograph for each station
    """
    # Get config directory
    if (len(sys.argv) == 2):
    	hg_config = sys.argv[1]
	print ("Using config: %s" % hg_config)
    else:
    # No script path passed on command line, assume "/usr/local/sbin"
	hg_config = os.path.join("/usr/local/sbin/hydrographs.conf")

    if not os.path.isfile(hg_config):
        print ("No config file %s. Aborting" % hg_config)
        sys.exit(1)

    # Read configurations
    config = ConfigParser.ConfigParser()
    config.read(hg_config)
    min_hr  = config.getint("General", "min_hr")
    max_hr  = config.getint("General","max_hr")
    hr_col  = config.getint("General", "hr_col")
    data_dir= config.get("General", "data_dir")
    rain_dir= config.get("General", "rain_dir")
    map_dir = config.get("General", "map_dir")
    src_path= config.get("General", "src_path")
    dst_data_path   = config.get("General","dst_data_path")
    dst_rain_path    = config.get("General","dst_rain_path")
    dst_maps_path    = config.get("General","dst_maps_path")
    dst_arc_path    = config.get("General","dst_arc_path")
    disch_col   = config.getint("General", "disch_col")
    dt_str_col  = config.getint("General", "dt_str_col")
    ts_file     = config.get("General", "timestamp_file")
    data_file   = config.get("General", "disch_data_file")
    precip_file = config.get("General", "precip_data_file")
    precip_pdf  = config.get("General", "precip_pdf_file")
    map_file    = config.get("General", "map_data_file")
    log_file    = config.get("General", "logfile")
    out_graph_path = config.get("Web","out_graph_path")
    out_map_path= config.get("Web","out_map_path")
    out_pref    = config.get("Web", "out_pref")
    host    = config.get("Db","host")
    dbname  = config.get("Db","dbname")
    user    = config.get("Db","user")
    password= config.get("Db","password")
    web_archive = config.get("Web","web_archive")

    # Set up logging
    frmt='%(asctime)s %(levelname)-8s %(message)s'
    logging.basicConfig(level=logging.DEBUG, format=frmt, filename=log_file, filemode='a')
    logging.info("*** Hydrograph process started ***")
    # Get directory of new map csv file
        #mapdir = get_latest_mapdir()
        #if mapdir is not None:
        #   extract_map_data(mapdir)
	#   create_map_images(mapdir)

	# Get directory of new rain text files
	#raindir = get_latest_raindir()

	# Get directory of new frxst drainage data files
	#datadir = get_latest_datadir()
	#if datadir is None:
	#   exit
	#else:	
	#   data_rows = parse_frxst(datadir)
	#
        #   if (data_rows is None):
	#       sys.exit()
	#   else:
	    # we have data, go ahead
	    #   do_loop(data_rows)
	    # INSERT to the database
	    #	upload_flow_data(data_rows)
	    #	upload_model_timing(data_rows)
	    # Send email alerts
	    #	send_alerts()
	    #	send_special_alert()

	# If there are any new directories, run copy to archive
	#if (mapdir is None and datadir is None and raindir is None):
	#	exit
	#else:
	#	copy_to_archive(datadir, mapdir, raindir)
    for i in (data_dir, rain_dir, map_dir):
        print ("Calling copy_and_archive for: %s " % i)
        hg.copy_and_archive(i)
	
    logging.info("*** Hydrograph Process completed ***")
    # end of main()


if __name__ == "__main__":
    main()

