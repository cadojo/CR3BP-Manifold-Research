#!/usr/bin/sh
#
# Fetch JPL Horizons ephemeris files for all 
# of the ~popular~ solar system bodies
#
# Note: This script assumes the usage of `vec_tbl` and `vec_tbl.inp`,
# which are both JPL software with their own usage restrictions.
# If you choose to use JPL software, check that your use-case is in
# compliance with their licenses & restrictions. At the time of writing,
# it appears that `vec_tbl` and `vec_tbl.inp` are allowed for personal 
# use, and require permission for commercial use.
#
# Requirements: UNIX system, expect, inetutils, moreutils, sponge
# If you have a Windows system, check out the Windows Subsystem for Linux!
#
# Usage:
# 1) Download ftp://ssd.jpl.nasa.gov/pub/ssd/SCRIPTS/vec_tbl, and make it executable!
# 2) Download ftp://ssd.jpl.nasa.gov/pub/ssd/SCRIPTS/vec_tbl.inp
# 3) Edit vec_tbl.inp with your desired configuration. Some helpful edits are below:
#
#    set   EMAIL_ADDR    "youremail@provider.com"   ;
#    set   CENTER        "@ssb  "                   ;
#    set   REF_PLANE     "FRAME"                    ;
#    set   START_TIME    "2020-Jan-1"               ;
#    set   STOP_TIME     "2050-Jan-1"               ;
#    set   STEP_SIZE     "6h"                       ;
#    set   CSV_FORMAT    "YES"                      ;
#    set   VEC_TABLE     "2"                        ;
#    set   REF_SYSTEM    "J2000"                    ;
#    set   VEC_CORR      "1"                        ;
#    set   OUT_UNITS     "1"                        ;
#    set   CSV_FORMAT    "YES"                      ;
#    set   VEC_LABELS    "NO"                       ;
#    set   VEC_DELTA_T   "NO"                       ;
#    set   VEC_TABLE     "2"                        ;
#
# 4) Run this file! With the settings above (particularly OUT_UNITS == 1),
#    the data will be provided as [Julian Date (in days), x, y, z, vx, vy, vz], with km and km/s 
#    as units.
#
# References:
# How to use sponge: https://stackoverflow.com/a/6697219
# How to use sed to filter data out of file: https://stackoverflow.com/a/38978201
# How to use awk to filter out the datetime strings in the second column: https://unix.stackexchange.com/a/34686
#
# 

echo 'Fetching ephemeris for Mercury Barycenter...'
./vec_tbl       1       Mercury-Barycenter.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Mercury-Barycenter.txt | sponge Mercury-Barycenter.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Mercury-Barycenter.txt | sponge Mercury-Barycenter.txt

echo 'Fetching ephemeris for Venus Barycenter...'
./vec_tbl       2       Venus-Barycenter.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Venus-Barycenter.txt | sponge Venus-Barycenter.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Venus-Barycenter.txt | sponge Venus-Barycenter.txt

echo 'Fetching ephemeris for Earth-Moon Barycenter...'
./vec_tbl       3       Earth-Moon-Barycenter.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Earth-Moon-Barycenter.txt | sponge Earth-Moon-Barycenter.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Earth-Moon-Barycenter.txt | sponge Earth-Moon-Barycenter.txt

echo 'Fetching ephemeris for Mars Barycenter...'
./vec_tbl       4       Mars-Barycenter.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Mars-Barycenter.txt | sponge Mars-Barycenter.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Mars-Barycenter.txt | sponge Mars-Barycenter.txt

echo 'Fetching ephemeris for Jupiter Barycenter...'
./vec_tbl       5       Jupiter-Barycenter.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Jupiter-Barycenter.txt | sponge Jupiter-Barycenter.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Jupiter-Barycenter.txt | sponge Jupiter-Barycenter.txt

echo 'Fetching ephemeris for Saturn Barycenter...'
./vec_tbl       6       Saturn-Barycenter.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Saturn-Barycenter.txt | sponge Saturn-Barycenter.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Saturn-Barycenter.txt | sponge Saturn-Barycenter.txt

echo 'Fetching ephemeris for Uranus Barycenter...'
./vec_tbl       7       Uranus-Barycenter.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Uranus-Barycenter.txt | sponge Uranus-Barycenter.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Uranus-Barycenter.txt | sponge Uranus-Barycenter.txt

echo 'Fetching ephemeris for Neptune Barycenter...'
./vec_tbl       8       Neptune-Barycenter.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Neptune-Barycenter.txt | sponge Neptune-Barycenter.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Neptune-Barycenter.txt | sponge Neptune-Barycenter.txt

echo 'Fetching ephemeris for Pluto Barycenter...'
./vec_tbl       9       Pluto-Barycenter.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Pluto-Barycenter.txt | sponge Pluto-Barycenter.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Pluto-Barycenter.txt | sponge Pluto-Barycenter.txt

echo 'Fetching ephemeris for Sun...'
./vec_tbl       10      Sun.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Sun.txt | sponge Sun.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Sun.txt | sponge Sun.txt

echo 'Fetching ephemeris for Mercury...'
./vec_tbl       199     Mercury.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Mercury.txt | sponge Mercury.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Mercury.txt | sponge Mercury.txt

echo 'Fetching ephemeris for Venus...'
./vec_tbl       299     Venus.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Venus.txt | sponge Venus.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Venus.txt | sponge Venus.txt

echo 'Fetching ephemeris for Moon...'
./vec_tbl       301     Moon.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Moon.txt | sponge Moon.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Moon.txt | sponge Moon.txt

echo 'Fetching ephemeris for Earth...'
./vec_tbl       399     Earth.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Earth.txt | sponge Earth.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Earth.txt | sponge Earth.txt

echo 'Fetching ephemeris for Mars...'
./vec_tbl       499     Mars.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Mars.txt | sponge Mars.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Mars.txt | sponge Mars.txt

echo 'Fetching ephemeris for Jupiter...'
./vec_tbl       599     Jupiter.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Jupiter.txt | sponge Jupiter.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Jupiter.txt | sponge Jupiter.txt

echo 'Fetching ephemeris for Saturn...'
./vec_tbl       699     Saturn.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Saturn.txt | sponge Saturn.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Saturn.txt | sponge Saturn.txt

echo 'Fetching ephemeris for Uranus...'
./vec_tbl       799     Uranus.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Uranus.txt | sponge Uranus.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Uranus.txt | sponge Uranus.txt

echo 'Fetching ephemeris for Neptune...'
./vec_tbl       899     Neptune.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Neptune.txt | sponge Neptune.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Neptune.txt | sponge Neptune.txt

echo 'Fetching ephemeris for Pluto...'
./vec_tbl       999     Pluto.txt
sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' Pluto.txt | sponge Pluto.txt
awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' Pluto.txt | sponge Pluto.txt

echo 'All done!'
