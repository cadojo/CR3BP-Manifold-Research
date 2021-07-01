#!/bin/sh
# Wraps NASA JPL's `vec_tbl` script for ease of operation.

fetch_ephemeris() {
  NAIF_ID=$1
  OUTPUT_FILE=$2
  ./vec_tbl $NAIF_ID $OUTPUT_FILE
  sed -n '/\$\$SOE/,/\$\$EOE/{//!p;}' $OUTPUT_FILE | sponge $OUTPUT_FILE 
  awk -F , 'BEGIN {OFS=FS}  {$2=""; sub(",,", ","); print}' $OUTPUT_FILE | sponge $OUTPUT_FILE
  echo "Fetched and formatted ephemeris data for body $NAIF_ID."
}
