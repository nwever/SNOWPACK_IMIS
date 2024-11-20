#!/bin/bash

#
# --- SETTINGS ---
#
begin_date="2024-09-01"		# start time of simulation leading up to stop&go
start_date="2024-09-02"		# start date stop&go simulation (should not be identical to begin_date)
end_date="2024-10-10"		# end date stop&go simulation
interval=1800			# in seconds, only integers possible
remove_meteo_before=172800		# 0: do not alter past meteo data in InputEditing block       >0: delete meteo data ${remove_meteo_before} seconds before timestep
remove_meteo_after=1		# 0: do not alter future meteo data in InputEditing block     1: delete future meteo data by using InputEditing

#
# --- END OF SETTINGS ---
#
stn=$1

if [ -z "${stn}" ]; then
	echo "Provide stn to run as first command line parameter."
	exit
fi

export TZ=UTC

# Convert the dates to unix time
current_date=$(date -d "${start_date}" +%s)
end_date_seconds=$(date -d "${end_date}" +%s)

# Find SNOWPACK command to base simulation on
snowpack_cl=$(fgrep ${stn} to_exec.lst | awk -F\&\& '{print $1}')

n=0
while [ "$current_date" -le "$end_date_seconds" ]; do
	d=$(date -d "@${current_date}" +"%Y-%m-%dT%H:%M")		# ISO time
	next_date=$((${current_date} + ${interval}))			# unix time

	# Create a proper ini file for stop-and-go simulations:
	# 1) suppress all meteorological data after end date
	# 2) read sno file from current_snow directory
	inifile=$(echo ${snowpack_cl} | awk '{for(i=1; i<=NF; i++) {if($i=="-c") {print $(i+1)}}}' | awk -F\/ '{print $NF}')
	inifile_add="./cfgfiles/io_${stn}_stop_and_go.ini"
	if (( ${n} > 0 )); then
		echo "IMPORT_BEFORE = ${inifile}" > ${inifile_add}
		echo "[InputEditing]" >> ${inifile_add}
		if (( $remove_meteo_after )); then
			# Determine the next date that will be executed after being done with the current date. We need this to suppress meteo data from the next date onward.
			next_date_d=$(date -d "@${next_date}" +"%Y-%m-%dT%H:%M")	# ISO time
			# Delete meteo data from the future
			echo "*::edit1         = EXCLUDE" >> ${inifile_add}
			echo "*::arg1::params  = *" >> ${inifile_add}
			echo "*::arg1::when    = ${next_date_d} - ${end_date}" >> ${inifile_add}
		fi
		if (( ${remove_meteo_before} )); then
			# Determine the next date that will be executed after being done with the current date. We need this to suppress meteo data from the next date onward.
			prev_date=$((${current_date} - ${interval} - ${remove_meteo_before}))		# unix time
			prev_date_d=$(date -d "@${prev_date}" +"%Y-%m-%dT%H:%M")			# ISO time
			# Delete meteo data from the past
			echo "*::edit2         = EXCLUDE" >> ${inifile_add}
			echo "*::arg2::params  = *" >> ${inifile_add}
			echo "*::arg2::when    = 1000-01-01 - ${prev_date_d}" >> ${inifile_add}
		fi
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
	to_exec=$(echo ${snowpack_cl} | awk -v n=${n} -v b=${begin_date} -v d=${d} -v inifile=${inifile_add} '{for(i=1; i<=NF; i++) {if(i>1) {printf " "}; if($i=="-b") {if(n==0) {printf("-b %s", b)}; i++} else if($i=="-e") {printf("-e %s", d); i++} else if($i=="-c" && n>0) {printf("-c %s", inifile); i++} else if($i==">" && n>0) {printf "-r >>"} else {printf "%s", $i}}}')
	# Print progress on screen
	if (( ${n} > 0 )); then
		echo "Running stop&go for ${stn} up to ${d}"
	else
		echo "Running for ${stn} from ${begin_date} up to ${d}"
	fi
	# Execute simulation
	eval ${to_exec}

	# Advance the current_date to the next_date
	current_date=${next_date}
	let n=${n}+1
done
