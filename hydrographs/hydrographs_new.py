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
               simplified the main() function
"""

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.dates as md
import datetime,tarfile,subprocess
import numpy as np
import os, csv, sys, errno, shutil
import psycopg2
import ConfigParser, logging
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart


def main():
	"""
	Loops thru each of the source data directories, checking if there is new data 
	When a new data file is found, it is processed, then copied to the web dir
	and the original data is archived and deleted.
	Processing is different for each type of source data
	"""
	#mapdir = get_latest_mapdir()
	#if mapdir is not None:
	# extract_map_data(mapdir)
	# create_map_images(mapdir)

	# Get directory of new rain text files
	#raindir = get_latest_raindir()

	# Get directory of new frxst drainage data files
	#datadir = get_latest_datadir()
	#if datadir is None:
	# exit
	#else:  
	#   data_rows = parse_frxst(datadir)
	#
	#   if (data_rows is None):
	#	   sys.exit()
	#   else:
		# we have data, go ahead
		#   do_loop(data_rows)
		# INSERT to the database
		#   upload_flow_data(data_rows)
		#   upload_model_timing(data_rows)
		# Send email alerts
		#   send_alerts()
		#   send_special_alert()

	# If there are any new directories, run copy to archive
	#if (mapdir is None and datadir is None and raindir is None):
	#	   exit
	#else:
	#	   copy_to_archive(datadir, mapdir, raindir)
	logging.info("*** Hydrograph processing started ***")
	for the_dir in (data_dir, rain_dir, map_dir):
		the_dir = os.path.join(src_path, the_dir)
		for d in os.listdir(the_dir):
			# Check if the new data dir has been created
			if os.path.isdir(os.path.join(the_dir, d)):
				# There is a new directory, now check if there are any file
				new_data_path = os.path.join(the_dir, d)
				f = os.listdir(new_data_path)
				if len(f) == 0:
					logging.info("Files in %s not yet available" % new_data_path)
				else:
					# We have new data files, start processing
					# The frxst data
					if data_dir in the_dir:
						# call parse_frxst with just the last part of the directory to the new data
						data_rows = parse_frxst(new_data_path)
						if (data_rows is None):
							sys.exit()
						else:
							do_loop(data_rows)
							# INSERT to the database
							upload_flow_data(data_rows)
							upload_model_timing(data_rows, new_data_path)
							# Send email alerts
							send_alerts()
							send_special_alert()

					# The maps
					if map_dir in the_dir:
						# Process only the csv file (not PDFs)
						logging.debug("Process map in %s" % the_dir)
						if 'csv' in new_data_path:
							extract_map_data(new_data_path)
							create_map_images(new_data_path)

					# The precip file (nothing to do, just go on to copy and archive)
					# Run the copy_and_archive function for each dir
					# Pass only the *last part* of the path to the function for creating final archive locations
					copy_and_archive(the_dir, d)

	logging.info("*** Hydrograph Processing completed ***")
	# end of main()


def send_alerts():
	""" 
	Send an email to each user, based on the level she requests,
	listing the hydro stations, and the max flow expected at that station
	for stations with flow return rate >= the level the user asks for
	rate = 0 means no alerts
	rate = 1 means send alerts for any flow > 1 cube per sec
	rate = 2 means send alerts for any flow above 2 yr return rate
	rate = 3 means send alerts for any flow above 5 yr return rate
	etc...
	"""
	# First get list of users with rate >0
	global host
	global dbname
	global user
	global password
	
	conn_string = "host='"+host+"' dbname='"+dbname+"' user='"+user+"' password='"+password+"'"
	try:
		conn = psycopg2.connect(conn_string)
		curs = conn.cursor()
		sql = "SELECT full_name, email_addr, reshut_num, alert_level, pk_uid FROM users WHERE active='t' and alert_level>0"
		curs.execute(sql)
		users = curs.fetchall()
	except psycopg2.DatabaseError, e:
		logging.error('Error %s',	e)
		sys.exit(1)

	# smtp connection details from conf file
	smtp_user = config.get("SMTP","smtp_user")
	smtp_pass = config.get("SMTP", "smtp_pass")
	smtp_server = config.get("SMTP", "smtp_server")
	smtp_port = config.getint("SMTP", "smtp_port")

	# Loop thru users and get all stations with return period equal or above the user's request
	for u in users:
		#logging.info("Sending alert to User: %s with ID: %s at: %s for return period %s" ,u[0], u[4], u[1], u[3])
		# For each user, find the hydrographs she has access to, 
		# with return rate above her requested level
		sql =			 "SELECT h.station_name, m.max_flow, to_char(m.max_flow_ts,'DD-MM-YYYY HH24:MI') "
		sql +=			" FROM max_flows AS m JOIN hydrostations AS h ON m.station_num=h.station_num "
		sql +=			" WHERE h.reshut_num IN (SELECT reshut_num FROM access WHERE user_id=%s)"
		sql +=			" AND m.flow_level >= %s AND h.active='t';"
		data = (u[4], u[3])
		curs.execute(sql, data)
		stations = curs.fetchall()
		alert_count = curs.rowcount
		if alert_count == 0:
			continue
		
		logging.info ("Found %s stations with alert for user %s ." % (alert_count, str(u[1])))
	
		# Setup smtp connection
		svr = smtplib.SMTP(smtp_server, smtp_port)
		sendfrom = 'micha@arava.co.il'
		rcptto = u[1]
		# Start constructing email message
		fh = open('alert_header.txt','r')
		f = open('alert_msg.txt','r')
		ff= open('alert_footer.txt','r')
		body_text = fh.read()
		body_text += "שלום %s :" % str(u[0])
		body_text += f.read()
		for h in stations:
		#logging.info("ALerting: %s for station: %s. Max Flow: %s",u[0], h[0], h[1])
			body_text += "<tr><td>%s</td><td style=\"text-align:center;\">%s</td><td style=\"text-align:center;\" dir=ltr>%s</td></tr>" % ( str(h[0]), str(h[1]), str(h[2]) )
		
		body_text += ff.read()
		msg = MIMEText(body_text, 'html')
		msg['From'] = sendfrom
		msg['To'] = rcptto
		msg['Subject'] = "WRF-Hydro alert"
		# message is ready, perform the send
		try:
			svr.ehlo()
			svr.starttls()
			svr.ehlo()
			svr.login(smtp_user,smtp_pass)
			svr.sendmail(sendfrom, rcptto, msg.as_string())
		except smtplib.SMTPException, e:
			logging.error("SMTP failed: %s" % str(e))
		finally:
			svr.quit()


def send_special_alert():
        """
	Sends an alert email to only 1 address 
	when any of the hydrostations will have a max_flow > 1.0 cubic meter per hr
	"""
	global host
	global dbname
	global user
	global password

	conn_string = "host='"+host+"' dbname='"+dbname+"' user='"+user+"' password='"+password+"'"
	try:
		conn = psycopg2.connect(conn_string)
		curs = conn.cursor()
		sql = "SELECT * FROM station_alert_list;"
		curs.execute(sql)
		station_list = curs.fetchall()
	except psycopg2.DatabaseError, e:
		logging.error('Error %s',			 e)
		sys.exit(1)
	
	cnt_list=len(station_list)
	if (cnt_list == 0):
		logging.info ("No stations with flow above 1 cubic meter.")		 
	else:
		logging.info ("Emailing list of %s stations with flow above 1 cubic meter." % cnt_list)
	# smtp connection details from conf file
		smtp_user = config.get("SMTP","smtp_user")
		smtp_pass = config.get("SMTP", "smtp_pass")
		smtp_server = config.get("SMTP", "smtp_server")
		smtp_port = config.getint("SMTP", "smtp_port")
		
		svr = smtplib.SMTP(smtp_server, smtp_port)
		sendfrom = 'floodalerts@gmail.com'
		rcptto = 'floodalerts@gmail.com'

		body_text = "מספר התחנות עם זרימה מעל 1 קוב: %s\n" % cnt_list
		body_text += "<table><tr><th>מס. תחנה</th><th>שם תחנה</th><th>זרימה מקס.</th><tr>"
		for r in station_list:
			body_text += "<tr><td>%s</td><td>%s</td><td>%s</td></tr>" % (str(r[0]),str(r[1]),str(int(r[3])))

		body_text += "</table>"

		msg = MIMEText(body_text, 'html')
		msg['From'] = sendfrom
		msg['To'] = rcptto
		msg['Subject'] = "Stations with flow above 1 cubic meter"
		# message is ready, perform the send
		try:
			svr.ehlo()
			svr.starttls()
			svr.ehlo()
			svr.login(smtp_user,smtp_pass)
			svr.sendmail(sendfrom, rcptto, msg.as_string())
                except smtplib.SMTPException, e:
			logging.error("SMTP failed: %s" % str(e))
		finally:
			svr.quit()			


def probability_period(l):
  """
  Check which level a hydro station is in, and return a string 
  to put into the graph title
  """
  prob_reply=""
  if ((l is None) | (l == -1)):
    prob_reply=" (No probability data)"
  elif l==0:
    prob_reply=" No flow"
  elif l==1:
    prob_reply=" less than 2 years"
  elif l==2:
    prob_reply=" 2 to 5 years"
  elif l==3:
    prob_reply=" 5 to 10 years"
  elif l==4:
    prob_reply=" 10 to 25 years"
  elif l==5:
    prob_reply=" 25 to 50 years"
  elif l==6:
    prob_reply=" 50 to 100 years"
  else :
    prob_reply=" greater than 100 years"

  return prob_reply


def get_stationid_list():
    """
    Make a postgresql database connection and query for a list of all station ids
    Get both the hydro_station ids and the drain_point ids
    return the list
    """
    global host
    global dbname
    global user
    global password

    conn_string = "host='"+host+"' dbname='"+dbname+"' user='"+user+"' password='"+password+"'"
    try:
        conn = psycopg2.connect(conn_string)
        curs = conn.cursor()
        sql = "SELECT id FROM hydrostations WHERE active='t' UNION SELECT id FROM drain_points WHERE active='t'"
        curs.execute(sql)
        rows = curs.fetchall()
        return rows
    except psycopg2.DatabaseError, e:
        logging.error('Error %s',  e)	       
        sys.exit(1)		 
    finally:
        if conn:
            conn.close()


def get_station_num(id):
  """
  Make a postgresql database connection and get the station_num 
  from the hydrograph view for a given station id
  return the number
  """
  # First get configurations
  global host
  global dbname
  global user
  global password

  conn_string = "host='"+host+"' dbname='"+dbname+"' user='"+user+"' password='"+password+"'"
  try:
    conn = psycopg2.connect(conn_string)
    curs = conn.cursor()
    sql = "SELECT station_num FROM hg_locations WHERE id= %s;" % id
    curs.execute(sql)
    row = curs.fetchone()
    if (curs.rowcount <1):
      return None
    else:
      return row[0]

  except psycopg2.DatabaseError, e:
    logging.error('Error %s', e)		
    sys.exit(1)		 
  finally:
    if conn:
      conn.close()



def update_maxflow(num, mf, mt):
  """
  Update the database table "max_flows" with the maximum flow
  for a station_num (passed as parameters)
  Requery to get the flow level value (set by a trigger)
  Return the flow level value
  """
  # First get configurations
  global host
  global dbname
  global user
  global password

  conn_string = "host='"+host+"' dbname='"+dbname+"' user='"+user+"' password='"+password+"'"
  try:
    conn = psycopg2.connect(conn_string)
    curs = conn.cursor()
    sql = "UPDATE max_flows SET max_flow=%s, max_flow_ts=%s WHERE station_num=%s;"
    data = (mf, mt, num)
    #logging.debug("Executing: "+sql+data)
    curs.execute(sql, data)
    conn.commit()
  except psycopg2.DatabaseError, e:
    logging.error('Error %s',e)
    sys.exit(1)

  # After update the flow level has been set in the db table (by a trigger)
  # Query for and return the flow level value
  try:
    sql = "SELECT flow_level FROM max_flows WHERE station_num = %s"
    data = (num,)
    curs.execute(sql, data)
    row = curs.fetchone()
    cnt = curs.rowcount
    if (cnt == 1):
      l = row[0]
    else:
      l = None
  
  except psycopg2.DatabaseError,e:
    logging.error('Error %s', e)
  finally:
    if conn:
      conn.close()
	
  return l



def create_graph(prob, num, disch, hrs, dt):
    """ 
    Creates a hydrograph (png image file) using the array of discharges from the input parameter
     """
    global out_graph_path
    global out_pref
    # Make a name for the date-specific target directory

    out_dir = os.path.join(out_graph_path, dt[:10])
    # Make sure target directory exists
    try:
	os.makedirs(out_dir)
    except OSError:
	if os.path.exists(out_dir):
	    pass
	else:
	    raise

    logging.info("Creating graph for station num: %s",str(num))
    fig = plt.figure()
    plt.xlabel('Hours')
    plt.ylabel('Discharge (m3/sec)')
    stnum=str(num)
    plt.suptitle('Station Number: '+ stnum, fontsize=18)
    prob_str="Return period: "+prob
    plt.title(prob_str,size=14)
    plt.figtext(0.13, 0.87, "Initialized: "+dt, size="medium", weight="bold", backgroundcolor="#EDEA95")
    ln = plt.plot(hrs,disch)
    # Get max discharge to size the graph
    try:
	dis_max = max(disch)
    except:
	dis_max = 0

    if dis_max <= 10:
	y_max = 10
    else:
	y_max = 1.05*dis_max
	
    plt.ylim(ymin=0, ymax=y_max)
    plt.setp(ln, linewidth=3, color='b')
    # Setup date format for X axis
    xfmt = md.DateFormatter('%d-%m-%Y %H:%M')
    plt.gca().xaxis.set_major_formatter(xfmt)
    ax = fig.add_subplot(111)
    ax.xaxis_date() 
    plt.setp(ax.get_xticklabels(), rotation=30, fontsize=7)
    outpng=os.path.join(out_dir,out_pref + stnum + ".png")
    plt.savefig(outpng)



def do_loop(data_rows):
	"""
	Loops thru the list of station ids, 
	For each id, search for those lines in data that match that id
	Obtains the discharge and hour values, and accumulates them into lists
	Send those lists to the create graph function
	"""
	# Get the list of station ids
	ids = get_stationid_list()
			
	for i in range(0,len(ids)):
		id = ids[i][0]
		logging.info("Working on station id: %s",str(id))
		datai = []
		for row in data_rows:
		# THe third column (numbered from 0) has the station id
		# Collect all data for one station into a data array
			if (int(row[3]) == id):
				datai.append(row)
	
		# Initialize the two arrays for hours and discharge
		hrs=[]
		disch=[]
		dis_times=[]
		max_disch=0
		if (len(datai) == 0):
			logging.warning("No data for id: %s", str(id))
			exit
		else:
			# Grab the date for use later in the graph (needed only once)
			date_str = datai[1][5]
			#logging.debug("Data for date: ",date_str)
			max_disch_time = datai[1][dt_str_col]

			for j in range(len(datai)):
				# Collect the date strings and discharge from this subset of data
				# Get hour and discharge column from config
				hr = (int(datai[j][hr_col]))/3600
				dis_time = matplotlib.dates.datestr2num(datai[j][dt_str_col])
				# Limit graph from minimum hour (from config) to max hour 
				# Never mind this 48 hour check, depend only on the length of the run
				#if (hr>min_hr and hr<=max_hr):
				hrs.append(hr)
				dis_times.append(dis_time)
				# Get "disch_col" column: has the discharge in cubic meters
				dis = float(datai[j][disch_col])
				disch.append(dis)
				# Keep track of the maximum discharge and time for this hydro station
				if dis>max_disch:
					max_disch = dis
					max_disch_time = datai[j][dt_str_col]

			# Now use the max_disch to update the maxflows database table
			# and get back the flow_level for this station
			station_num = get_station_num(int(id))
			# Continue ONLY if level actually has value
			try:
				level = update_maxflow(int(station_num), max_disch, max_disch_time)
				#logging.debug( "Station num: %s has max discharge: %s", str(station_num), str(max_disch))
				# Find which return period this max flow is in
				prob_str = probability_period(level) 
				# Create the graph
				create_graph(prob_str, station_num, disch, dis_times, date_str)
			except:
				logging.warning( "No station with id: %s",str(id))


#def get_latest_raindir():
#    """
#    Scans the WRF_Rain directory to get timestamp
#    finds the newest (if it is newer than the timestamp file)
#    returns the newest precip directory
#    """
#    global rain_path
#    global ts_file
#    global precip_file
#
#  # First read existing timestamp from last timestamp file
#    try:
#	f = open(ts_file,"r+")
#    # Convert timestamp to int. We don't care about fractions of seconds
#	last_ts = int(float(f.readline()))
#
#    except IOError as e:
#    # Can't get a value from the last timesatmp file. Assume 0
#	logging.warning( "Can't access timestamp file: %s", e.strerror)
#	last_ts = 0
#	f = open(ts_file, "w")
#
#    new_rain_dir = None
#    for d in os.listdir(rain_path):
#	if os.path.isdir(os.path.join(rain_path,d)):
#	    logging.debug("Trying path: %s", os.path.join(rain_path,d,precip_file))
#	    try:
#		ts = int(os.path.getmtime(os.path.join(rain_path,d,precip_file)))
#	    # Compare timestamp for each frxst file in each subdir 
#	    # with the value from the last timestamp file
#			# The last timestamp was already updated by the get_latest_datadir() function
#			# The new map_dir *should* be newer than the last datadir (uploaded later from Model)
#			# Just in case, take off 10 seconds from last (datadir) timestamp 
#			# to be sure to find newer rain files
#		if ts >= last_ts-10:
#		    new_rain_dir = d
#    
#	    except OSError as e:
#		logging.warning("Rain data file in subdir: %s not yet available. %s", d, e.strerror)
#
#  # If there is no newer frxst file, return None
#  # otherwise return the subdir of the new data
#  # and write out the new timestamp to the last timestamp file (for next time)
#    if new_rain_dir is None:
#	logging.info("No new rain data file")
#	f.close()
#	return None
#
#    else:
#	f.close()
#	logging.info("Using rain directory: %s", new_rain_dir)
#    
#    return new_rain_dir
#
#
#
#def get_latest_mapdir():
#    """
#    Scans the precip directory to get timestamp
#    finds the newest (if it is newer than the timestamp file)
#    returns the newest precip directory
#    """
#    global map_path
#    global ts_file
#    global map_file
#
#  # First read existing timestamp from last timestamp file
#    try:
#	f = open(ts_file,"r+")
#    # Convert timestamp to int. We don't care about fractions of seconds
#	last_ts = int(float(f.readline()))
#
#    except IOError as e:
#    # Can't get a value from the last timesatmp file. Assume 0
#	logging.warning( "Can't access timestamp file: %s", e.strerror)
#	last_ts = 0
#	f = open(ts_file, "w")
#
#    new_map_dir = None
#    for d in os.listdir(map_path):
#	if os.path.isdir(os.path.join(map_path,d)):
#	    logging.debug("Trying path: %s", os.path.join(map_path,d,map_file))
#	    try:
#		ts = int(os.path.getmtime(os.path.join(map_path,d,map_file)))
#	    # Compare timestamp for each frxst file in each subdir 
#	    # with the value from the last timestamp file
#			# The last timestamp was already updated by the get_latest_datadir() function
#			# The new map_dir *should* be newer than the last datadir (uploaded later from Model)
#			# Just in case, take off 10 seconds to be sure to find newer files
#		if ts >= last_ts-10:
#		    new_map_dir = d
#	    except OSError as e:
#		logging.warning("Precipitation map files in subdir: %s not yet available. %s", d, e.strerror)
#
#	# If there is no newer frxst file, return None
#	# otherwise return the subdir of the new data
#	# and write out the new timestamp to the last timestamp file (for next time)
#    if new_map_dir is None:
#	logging.info("No new precipitation map files")
#	f.close()
#	return None
#
#    else:
#	f.close()
#	logging.info("Using precipitation directory: %s", new_map_dir)
#    
#    return new_map_dir
#


def extract_map_data(map_dir):
	"""
	Extract the set of precip csv files from tar.gz 
	into the same directory
	"""
	global map_file

	arc = os.path.join(map_dir, map_file)
	p = tarfile.open(arc)
	p.extractall(path=map_dir)
	p.close()
	cnt = len([f for f in os.listdir(map_dir) 
		 if f.endswith('.txt') and os.path.isfile(os.path.join(map_dir, f))])
	if cnt>0:
		logging.info("Untarred %s csv files from %s" % (cnt,arc))
	else:
		logging.warning("Untar of %s FAILED" % arc)

	return cnt



def create_map_images(map_dir):
	"""
	Call a GRASS script to create a set of images of precip maps
	Move all images to the web directory
	Call imageMagick "convert" to make animation
	"""
	global out_map_path
	
	grass_script = 'create_precip_map.sh'
	grass_script_path = os.path.join('/usr/local/sbin', grass_script)
	cmd = 'su - ihs -c "%s %s 2>/dev/null"' % (grass_script_path,map_dir) 
	logging.debug("Starting GRASS script: %s" % (cmd,))
	retn = subprocess.call(cmd, shell=True)
	if (retn == 0):
		logging.info("GRASS script completed successfully")
		# Move all image files to the web dir
		try:
			shutil.copytree(map_dir, out_map_path)
			logging.info("Image files copied to: %s " % (out_map_path,))
		except (IOError, OSError) as e:
			logging.error("Error %s from: %s to: %s", (repr(e), map_dir, out_map_path))
		# Reset the symlinks in the web directory of maps
		link_name = "precip_animated.gif"
		link_path = os.path.join(out_map_path, link_name)
		if os.path.islink(link_path):
			os.unlink(link_path)

		link_src = os.path.join(out_map_path, os.path.basename(map_dir), link_name)
		os.symlink(link_src, link_path)
		logging.info("Precip animation now linked to: %s" % link_src) 
		
		# Also link to the directory of png images
		link_dir_name = "precip_images"
		link_dir_path = os.path.join(out_map_path, link_dir_name)
		if os.path.islink(link_dir_path):
			os.unlink(link_dir_path)

		link_dir_src = os.path.join(out_map_path, os.path.basename(map_dir))
		os.symlink(link_dir_src, link_dir_path)
		logging.info("Precip images directory now linked to: %s" % link_dir_src) 

	else:
		logging.error("GRASS script FAILED")
	
	return retn

#def get_latest_datadir():
#	"""
#	Scans the output directory to get timestamps of each
#	Finds the directory with a timestamp newer than the timestamp
#	stored in the "last_timestamp" file
#	Returns the newer data directory
#	"""
#	global data_path
#	global ts_file
#	global data_file
#
#	# First read existing timestamp from last timestamp file
#	try:
#		f = open(ts_file,"r+")
#		# Convert timestamp to int. We don't care about fractions of seconds
#		last_ts = int(float(f.readline()))
#
#	except IOError as e:
#	# Can't get a value from the last timesatmp file. Assume 0
#		logging.warning( "Can't access timestamp file: %s", e.strerror)
#		last_ts = 0
#		f = open(ts_file, "w")
#
#	new_ts = None
#	new_data_dir = None
#	for d in os.listdir(data_path):
#		if os.path.isdir(os.path.join(data_path,d)):
#			#logging.debug("Trying path: %s", os.path.join(data_path,d))
#			try:
#				ts = int(os.path.getmtime(os.path.join(data_path,d,data_file)))
#				# Compare timestamp for each frxst file in each subdir 
#				# with the value from the last timestamp file
#				if ts > last_ts:
#					new_ts = ts
#					# Reset last_ts so that if the directories are not checked in order
#					# The most recent timestamp will always be used
#					last_ts = ts
#					new_data_dir = d
#		
#			except OSError as e:
#				logging.warning("Data file in subdir: %s not yet available. %s", d, e.strerror)
#
#	# If there is no newer frxst file, return None
#	# otherwise return the subdir of the new data
#	# and write out the new timestamp to the last timestamp file (for next time)
#	if new_ts is None:
#		logging.info("No new data file")
#		f.close()
#		return None
#
#	else:
#		f.seek(0)
#		logging.debug("Updating last_timestamp to: "+str(new_ts))
#		f.write(str(new_ts))
#		f.truncate()
#		f.close()
#		logging.info("Using data directory: %s", new_data_dir)
#		
#	return new_data_dir
#


def parse_frxst(new_data_dir):
	"""
	Scan the input data file, and get all rows into a list of lists
	Add a column "datestr" wihich concatenates the date and hour
	Return the list
	"""
	global data_path
	global data_file

	input_file = os.path.join(new_data_dir, data_file)
	data_rows=[]
	try:
		f = open(input_file, 'rb')
		for line in f.readlines():
			# Force discharge to a float
			secs, dt, hr, id, disch = int(line[0:8]), line[9:19], line[20:28], int(line[32:36]), float(line[59:66])
		# New frxst format:
			#secs, dt, hr, id, disch = int(line[0:7]), line[9:18], line[20:27], int(line[32:35]), float(line[59:65])
			dt_str = dt+" "+hr
			atuple=(secs,dt,hr,id,disch,dt_str)
			data_rows.append(atuple)
		
		if (len(data_rows) > 1):
			logging.info("Data file contains %s rows", str(len(data_rows)))
		else:
			logging.error("No rows in data file!")
			return None

	except IOError as e:
		if e.errno == errno.EACCES:
			logging.error("Data file not accessible: %s",e.strerror)
		else:
			logging.error("Data file not available: %s",e.strerror)
		raise
		return None

	f.close
	return data_rows


def upload_flow_data(data_rows):
	"""
	Creates a database connection,
	inserts all rows from the data_rows array
	into the db table predicted_flow_data
	"""
	# First get configurations
	global host
	global dbname
	global user
	global password

	conn_string = "host='"+host+"' dbname='"+dbname+"' user='"+user+"' password='"+password+"'"
	try:
		conn = psycopg2.connect(conn_string)
		curs = conn.cursor()
		logging.info("Beginning upload of flow data to database")
		for row in data_rows:
			dt = row[1]+" "+row[2]
			id = row[3]
			mf = row[4]
			data = (dt, id, mf)
			sql = "INSERT INTO model_flow_data (model_timestamp, station_id, max_flow) VALUES (%s, %s, %s)"
			curs.execute(sql,data)

		conn.commit()
		logging.info("Database upload completed")

	except psycopg2.DatabaseError as e:
		logging.error('Error %s', repr(e))
		sys.exit(1)
	finally:
		if conn:
			conn.close()



def upload_model_timing(data_rows, data_dir):
	"""
	Grab the init date-time of the gfs data (from the first row of data_rows)
	and the time the model completed (from the last_timestamp file)
	INSERT a row into the model_timing database table with three timestamps:
	gfs init, wrf completed, and graphs available
	"""
	global host
	global dbname
	global user
	global password
	global data_file

	# Get init hour from the data
	gfs_init = data_rows[1][5]
	# Get time model completed from a data file

	mod_time = os.path.getmtime(os.path.join(data_dir, data_file))
	model_complete = datetime.datetime.fromtimestamp(mod_time).strftime('%Y-%m-%d %H:%M')
	graphs_complete = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
	#print "GFS: "+str(gfs_init)+", MODEL: "+str(model_complete)+", GRAPHS: "+str(graphs_complete) 

	conn_string = "host='"+host+"' dbname='"+dbname+"' user='"+user+"' password='"+password+"'"
	logging.info("Beginning upload of model timing to database")
	try:
		conn = psycopg2.connect(conn_string)
		curs = conn.cursor()
		
		data = (str(gfs_init), str(model_complete), str(graphs_complete))
		sql = "INSERT INTO model_timing VALUES (to_timestamp(%s,'YYYY-MM-DD HH24:MI'), "
		sql += "to_timestamp(%s,'YYYY-MM-DD HH24:MI'), to_timestamp(%s,'YYYY-MM-DD HH24:MI'))"
		curs.execute(sql, data)
		conn.commit()

	except psycopg2.DatabaseError, e:
		logging.error('Error %s', repr(e))
		sys.exit(1)
	finally:
		if conn:
			conn.close()

#def copy_to_archive(datadir, mapdir, raindir):
#    """ 
#    Copies the latest directory to the website archive directory
#    Also move the latest rainfall data files to the web archive
#    """
#    global web_archive
#    global data_path
#    global rain_path
#    global map_path
#    global out_map_path
#	
#    if datadir is not None:
#        destdatadir     = os.path.join(web_archive,'forecast',datadir)
#        srcdatadir      = os.path.join(data_path, datadir)      
#        try:
#	    shutil.copytree(srcdatadir, destdatadir)
#	    logging.info("Data files copied to: "+destdatadir)
#	except (IOError, OSError) as e:
#	    logging.error("Error %s copying from: %s to: %s" % (repr(e), datadir, web_archive))
#	
#    if raindir is not None:
#        destraindir     = os.path.join(web_archive,'rainfall')
#	srcraindir      = os.path.join(rain_path, raindir)
#	try:
#	    shutil.copytree(srcraindir, destraindir)
#	    logging.info("Rain files copied to: "+destraindir)
#	except (IOError, OSError) as e:
#	    logging.error("Error %s copying from: %s to: %s" % (repr(e), rain_path, web_archive))
#
#    if mapdir is not None:
#	srcmapdir       = os.path.join(map_path, mapdir)
#	dstmapdir       = os.path.join(out_map_path, mapdir)
#    	# Temporary for the pdf file...
#	dstmapdir2      = os.path.join(rain_path, mapdir)
#	try:
#            shutil.copytree(srcmapdir, dstmapdir)
#	    logging.info("Map files copied to: "+dstmapdir)
#	    shutil.copytree(srcmapdir, dstmapdir2)
#            logging.info("Map PDF copied to: "+dstmapdir2)
#	except (IOError, os.error) as e:
#            logging.error("Error %s copying from: %s, to: %s" % (repr(e), map_path, dstmapdir))
#	

def copy_and_archive (the_dir, new_data):
	""" 
	Copies each data directory to its place in the website
	creates tar archive of the date, and deletes the new data directory
	"the_dir" contains the full path to one of the three types of new data files,
	WRF_Data, WRF_Rain, or WRF_Maps
	"new_data" is the subdir of "the_dir" where the new files are located
	"""
	global dst_data_suffix
	global dst_rain_suffix
	global dst_maps_suffix
	global arc_path
	global web_site
	global web_archive

	#logging.warning("Configs: the_dir=%s new_data=%s " % (the_dir, new_data))
	if ('Data' in the_dir):
		dst = os.path.join(web_archive, dst_data_suffix)
		dst_arc = os.path.join(arc_path, dst_data_suffix)
		logging.info("Copying frxst to %s" % dst)
	elif ('Rain' in the_dir):
		dst = os.path.join(web_archive, dst_rain_suffix)
		dst_arc = os.path.join(arc_path, dst_rain_suffix)
		logging.info("Copying rain to %s" % dst)
	elif ('Maps' in the_dir):
		# Separate between the csv files and the PDFs
		if "csv" in new_data:
			dst = os.path.join(web_site, dst_maps_suffix)
		elif "map" in new_data:
			dst + os.path.join(web_archive, dst_rain_suffix)

		dst_arc = os.path.join(arc_path, dst_maps_suffix)
		logging.info("Copying maps to %s" % dst)
	else:
		logging.error("Unknown source data dir: %s" % the_dir)
		os.exit(1)

	full_src = os.path.join(the_dir, new_data)
	full_dst = os.path.join(dst, new_data)
	#logging.warning("Copying and archiving: Source=%s\tDest=%s\tArchive=%s" % (full_src, full_dst, dst_arc))
	# copy tree to destination
	try:
		shutil.copytree(full_src, full_dst)
		logging.info("Data files from %s copied to: %s" % (full_src, full_dst))
	except (IOError, OSError) as e:
		logging.error("Error %s: copying from: %s to: %s FAILED" % (repr(e), full_src, full_dst))
	
	# Create tar archive of tree
	tarname = new_data+".tar.gz"
	tarpath = os.path.join(dst_arc, tarname)
	try:
		arc = tarfile.open(tarpath, 'w:gz')
		arc.add(full_src)
		arc.close()
		logging.info("Created tar archive %s " % (tarpath,))
		shutil.rmtree(full_src)
		logging.info("Source dir %s removed" % full_src)
	except Exception as e:
		logging.error("Error: %s creating tar archive: %s FAILED" % (repr(e),tarpath))

	# After archiving, remove unnecessary files from the precip_maps directory of web site
	web_maps = os.path.join(web_site, dst_maps_suffix, new_data)
	cnt = 0
	for f in os.listdir(web_maps):
		if ".tar.gz" in f:
			os.unlink(os.path.join(web_maps,f))
			cnt = cnt+1
		if ".txt" in f:
			os.unlink(os.path.join(web_maps,f))
			cnt = cnt+1

	logging.warning("Removed %s files from web directory: %s" % (cnt,web_maps) )



if __name__ == "__main__":
	# Get config directory
	if (len(sys.argv) == 2):
		hg_config = sys.argv[1]
		print ("Using config: %s" % hg_config)
	else:
	# No script path passed on command line, assume "/usr/local/sbin"
		hg_config = "/usr/local/sbin/hydrographs.conf"

	if not os.path.isfile(hg_config):
		print ("No config file %s. Aborting" % hg_config)
		sys.exit(1)

	# Read configurations
	config = ConfigParser.ConfigParser()
	config.read(hg_config)
	min_hr  = config.getint("General", "min_hr")
	max_hr  = config.getint("General","max_hr")
	hr_col  = config.getint("General", "hr_col")
	src_path=config.get("General","src_path")
	data_dir= config.get("General", "data_dir")
	rain_dir= config.get("General", "rain_dir")
	map_dir = config.get("General", "map_dir")
	dst_data_suffix   = config.get("General","dst_data_suffix")
	dst_rain_suffix	= config.get("General","dst_rain_suffix")
	dst_maps_suffix	= config.get("General","dst_maps_suffix")
	arc_path	= config.get("General","arc_path")
	disch_col   = config.getint("General", "disch_col")
	dt_str_col  = config.getint("General", "dt_str_col")
	data_file   = config.get("General", "frxst_data_file")
	precip_file = config.get("General", "precip_data_file")
	precip_pdf  = config.get("General", "precip_pdf_file")
	map_file	= config.get("General", "map_data_file")
	log_file	= config.get("General", "logfile")
	out_graph_path = config.get("Web","out_graph_path")
	out_map_path= config.get("Web","out_map_path")
	out_pref	= config.get("Web", "out_pref")
	host	= config.get("Db","host")
	dbname  = config.get("Db","dbname")
	user	= config.get("Db","user")
	password= config.get("Db","password")
	web_archive = config.get("Web","web_archive")
	web_site = config.get("Web","web_site")

	# Set up logging
	frmt='%(asctime)s %(levelname)-8s %(message)s'
	logging.basicConfig(level=logging.DEBUG, format=frmt, filename=log_file, filemode='a')
	# Now start work
	main()

