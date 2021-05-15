# Fetch Ephemeris Data!

The `fetch_ephemeris.sh` script in this directory
provides an _example_ for how you can collect 
ephemeris data with your own constraints.
The `sed` and `awk` commands format the 
ephemeris data into a CSV file.  

The columns of the generated Ephemeris files
produced with the default configuration of 
`vec_tbl.inp` (as described in `fetch_ephemeris.sh`)
are:

1. Julian Day
2. Rx (km)
3. Ry (km)
4. Rz (km)
5. Vx (km/s)
6. Vy (km/s)
7. Vz (km/s)

