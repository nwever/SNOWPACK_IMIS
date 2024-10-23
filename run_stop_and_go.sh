#!/bin/bash

# Setttings
start_date="2024-09-01"
end_date="2024-10-10"
interval=1800			# in seconds, only integers possible
stn=$1

if [ -z "${stn}" ]; then
	echo "Provide stn to run as first command line parameter."
	exit
fi

# Convert the dates to unix time
current_date=$(date -d "${start_date}" +%s)
end_date_seconds=$(date -d "${end_date}" +%s)

n=0
while [ "$current_date" -le "$end_date_seconds" ]; do
	d=$(date -d "@${current_date}" +"%Y-%m-%dT%H:%M")

	# Determine the next date that will be executed after being done with the current date. We need this to suppress meteo data from the next date onward.
	next_date=$((${current_date} + ${interval}))			# unix time
	next_date_d=$(date -d "@${next_date}" +"%Y-%m-%dT%H:%M")	# ISO time

	# Create a proper ini file for stop-and-go simulations:
	# 1) suppress all meteorological data after end date
	# 2) read sno file from current_snow directory
	inifile=$(fgrep ${stn} to_exec.lst | awk '{for(i=1; i<=NF; i++) {if($i=="-c") {print $(i+1)}}}' | awk -F\/ '{print $NF}')
	inifile_add="./cfgfiles/io_${stn}_stop_and_go.ini"
	if (( ${n} > 0 )); then
		echo "IMPORT_BEFORE = ${inifile}" > ${inifile_add}
		echo "[InputEditing]" >> ${inifile_add}
		echo "*::edit1         = EXCLUDE" >> ${inifile_add}
		echo "*::arg1::params  = *" >> ${inifile_add}
		echo "*::arg1::when    = ${next_date_d} - ${end_date}" >> ${inifile_add}
		echo "[INPUT]" >> ${inifile_add}
		echo "SNOWPATH = ./current_snow" >> ${inifile_add}
	fi

	# Do a few modifications to the execute command.
	# 1) Set the -e end time correctly
	#  After the first iteration:
	# 2) Remove the -b start time. After the first iteration, start time should be determined from the sno file
	# 3) Replace the ini file with the stop-and-go ini file
	# 4) Make sure to specify the -r restart option
	# 5) Append to the logfile (>>)
	to_exec=$(fgrep ${stn} to_exec.lst | awk -v n=${n} -v d=${d} -v inifile=${inifile_add} '{for(i=1; i<=NF; i++) {if(i>1) {printf " "}; if(n>0 && $i=="-b") {i++} else if($i=="-e") {printf("-e %s", d); i++} else if($i=="-c" && n>0) {printf("-c %s", inifile); i++} else if($i==">" && n>0) {printf "-r >>"} else {printf "%s", $i}}}')
	eval ${to_exec}

	# Advance the current_date to the next_date
	current_date=${next_date}
	let n=${n}+1
done
