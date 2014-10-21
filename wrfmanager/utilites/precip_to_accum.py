#!/usr/bin/python
import csv,sys,argparse,os

def add_accum_rain(csvin): 
    """
    Parse CSV of rain data,
    Add accumulated rain for each location at each time span
    Save, overwriting the original
    """
    csvtmp = csvin+".tmp"
	try:
		os.rename(csvin, csvtmp)
	except os.Error, e:
		sys.exit(str(e))

    # open the temp file for reading
    with open(csvtmp,"r") as infile:
        csvrdr = csv.reader(infile)
        col_headers = csvrdr.next()
        dataout = []
        i = 0
        r = csvrdr.next()
        next_id = 0
        accum = 0.0
        for r in csvrdr:
            st_id, st_name, start_tm, end_tm, precip = r
            if (next_id ==0):
                # Initialize next_id the first time
                next_id = st_id

            if (next_id == st_id):
                # accumulate precip
                accum = float(precip)+accum
            else:
                accum = 0.0
                next_id=st_id

            newr = [st_id, st_name, start_tm, end_tm, precip, '%.1f' % accum]
            dataout.append(newr)

	try:
		infile.close()
	except:
		sys.exit(sys.exc_info()[0])

    # rewrite back out to the same original file name
    with open(csvin, "w") as outfile:
        csvwrtr = csv.writer(outfile)
        for r in dataout:
            csvwrtr.writerow(r)
	try:
	    outfile.close()
		sys.exit(0)
	except:
		sys.exit(sys.exc_info()[0])


# Main work starts here
parser = argparse.ArgumentParser("Get command line arguments")
parser.add_argument("-i", "--input", default=".", required=True, help="Input csv file of precipitation data")
# Get arguments
args = parser.parse_args()

add_accum_rain(args.input)
