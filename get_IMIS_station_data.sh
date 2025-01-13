# Note: invoke with "bash get_IMIS_station_data.sh full" to merge existing processed data as well. This is practical, since live data doesn't always follow directly on historical data.
# This can result in data gaps, that can be filled at a later stage when the historical data gets updated on the SLF server. Providing "full" as command line parameter merges the 3 data sources:
# (1) processed data in the ./smet/ folder, (2) downloaded historical data and (3) downloaded live data.
#
# SETTINGS
#
stnlst="WFJ2 SLF2"	# Leave empty to download all available stations listed in stations.csv
get_live_data=0		# 0: only historical data, 1: also download live data
					# Note: downloading live data implies an update. This means that it only downloads historical data, if there is no processed file yet, or if the last timestep in the processed file
					#       is from before the first time step in the live data. Otherwise, it will only download live data, and append to the existing processed file
make_meta_data_table=0	# Make meta data table (only possible within SLF network)
#
# END SETTINGS
#

# Check for command line option
if [[ "${1,,}" == "full" ]]; then
	fullmergeupdate=1
else
	fullmergeupdate=0
fi

# Make sure required directory structure exists
mkdir -p ./download/
mkdir -p ./smet/

if (( ${make_meta_data_table} )); then
	echo "#station_code lat lon elevation type warning_region drift_station_code wind_scaling_factor slope exposition" > station_meta.txt
fi

# Get the station list
curl -s -o ./download/stations.csv "https://measurement-data.slf.ch/imis/stations.csv"
sed -E 's/"([^"]*), ([^"]*)"/"\1__\2"/g' ./download/stations.csv > ./download/stations.csv.mod   # For more convenient processing, station names with commas are replaced by two underscores

# Extract structure of stations.csv.mod file
col_stnid=$(head -1 ./download/stations.csv.mod | awk -F, '{for(i=1; i<=NF; i++) {if($i=="station_code") {print i; exit}}}')
col_name=$(head -1 ./download/stations.csv.mod | awk -F, '{for(i=1; i<=NF; i++) {if($i=="label") {print i; exit}}}')
col_lon=$(head -1 ./download/stations.csv.mod | awk -F, '{for(i=1; i<=NF; i++) {if($i=="lon") {print i; exit}}}')
col_lat=$(head -1 ./download/stations.csv.mod | awk -F, '{for(i=1; i<=NF; i++) {if($i=="lat") {print i; exit}}}')
col_elev=$(head -1 ./download/stations.csv.mod | awk -F, '{for(i=1; i<=NF; i++) {if($i=="elevation") {print i; exit}}}')
col_type=$(head -1 ./download/stations.csv.mod | awk -F, '{for(i=1; i<=NF; i++) {if($i=="type") {print i; exit}}}')

if [ -z "${stnlst}" ]; then
	# If no stations are explicitly requested, download all
	stnlst=$(awk -F, -v c=${col_stnid} '(NR>1) {if(NR>2) {printf " "}; printf "%s", $c}' ./download/stations.csv.mod)
fi

for stnid in ${stnlst}
do
	if (( ${get_live_data} )); then
		# Get live data
		curl -s "https://measurement-api.slf.ch/public/api/imis/station/${stnid}/measurements" | jq --raw-output -r '([.[0] | keys_unsorted] | add | @csv), (.[] | [.[]] | @csv)' | tr -d '\"' > ./download/${stnid}_live.csv
		ts1=$(head -2 ./download/${stnid}_live.csv | tail -1 | awk -F, '{print(substr($2,1,19))}')	# First time step in live data
		if [ ! -e "./smet/${stnid}.smet" ]; then
			# If there is no processed data already, download historical data
			get_historical_data=1
		else
			ts0=$(tail -1 ./smet/${stnid}.smet | awk '{print $1}')	# Last time step in processed data
			if [[ "${ts1}" > "${ts0}" ]]; then
				# If the first time step from the live data is later than the last time step in the already processed data, then there might be a data gap. Get historical data again.
				get_historical_data=1
			else
				# Otherwise, we only need to obtain the live data
				get_historical_data=0
			fi
		fi
	else
		# If no live data is requested, we assume that historical data is requested
		get_historical_data=1
	fi

	# Get historical data
	if (( ${fullmergeupdate} )); then
		get_historical_data=1
	fi
	if (( ${get_historical_data} )); then
		curl -f -s -o ./download/${stnid}.csv https://measurement-data.slf.ch/imis/data/by_station/${stnid}.csv
		if [ ! -e "./download/${stnid}.csv" ]; then
			echo "Downloading ${stnid}.csv failed..."
			continue
		fi
	fi

	# Get meta data for station
	stnname=$(  awk -F, -v c=${col_stnid} -v s="${stnid}" -v r=${col_name} '{if($c==s) {print $r; exit}}' ./download/stations.csv.mod | sed 's/__/, /g' | tr -d '\"')
	latitude=$( awk -F, -v c=${col_stnid} -v s="${stnid}" -v r=${col_lat}  '{if($c==s) {print $r; exit}}' ./download/stations.csv.mod)
	longitude=$(awk -F, -v c=${col_stnid} -v s="${stnid}" -v r=${col_lon}  '{if($c==s) {print $r; exit}}' ./download/stations.csv.mod)
	altitude=$( awk -F, -v c=${col_stnid} -v s="${stnid}" -v r=${col_elev} '{if($c==s) {print $r; exit}}' ./download/stations.csv.mod)
	type=$(     awk -F, -v c=${col_stnid} -v s="${stnid}" -v r=${col_type} '{if($c==s) {print $r; exit}}' ./download/stations.csv.mod)

	# Get start time in historical data
	if (( ${get_historical_data} )); then
		col_date=$(head -1 ./download/${stnid}.csv | awk -F, '{for(i=1; i<=NF; i++) {if($i=="measure_date") {print i; exit}}}')
		if [ "${stnid}" == "WFJ2" ]; then
			# For WFJ we make an exception, because the IMIS type data starts later than the first time step in the file
			startTime="1999-08-04T11:00:00"
		else
			startTime=$(awk -F, -v r=${col_date} '(NR==2) {print substr($r,1,10) "T" substr($r,12,8); exit}' ./download/${stnid}.csv)
		fi
	else
		# If no historical data is downloaded, set startTime to an empty string, such that the start time can be derived from the live data
		startTime=""
	fi
	# Get end time
	if (( ${get_live_data} )); then
		col_date=$(head -1 ./download/${stnid}_live.csv | awk -F, '{for(i=1; i<=NF; i++) {if($i=="measure_date") {print i; exit}}}')
		endTime=$(tail -1 ./download/${stnid}_live.csv | awk -F, -v r=${col_date} '{print substr($r,1,10) "T" substr($r,12,8); exit}')
		if [ -z "${startTime}" ]; then
			# If no startTime present, determine it from live data
			startTime=${ts1}
		fi
	else
		endTime=$(tail -1 ./download/${stnid}.csv | awk -F, -v r=${col_date} '{print substr($r,1,10) "T" substr($r,12,8); exit}')
	fi

	# Create ini file for processing
	inifile="./download/io.ini"
	echo "[INPUT]" > ${inifile}
	echo "COORDSYS = CH1903" >> ${inifile}
	echo "COORDPARAM = NULL" >> ${inifile}
	echo "TIME_ZONE = 0" >> ${inifile}
	echo "METEO = CSV" >> ${inifile}
	echo "METEOPATH = ./download/" >> ${inifile}
	if (( ${get_historical_data} )); then
		echo "[INPUT]" >> ${inifile}
		echo "METEOFILE1 = ${stnid}.csv" >> ${inifile}
		echo "POSITION1 = latlon ${latitude} ${longitude} ${altitude}" >> ${inifile}
		echo "CSV1_NAME = ${stnname}" >> ${inifile}
		echo "CSV1_ID = ${stnid}" >> ${inifile}
		echo "CSV1_COLUMNS_HEADERS = 1" >> ${inifile}
		echo "CSV1_DATETIME_SPEC = YYYY-MM-DD HH24:MI:SS+00:00" >> ${inifile}
		echo "CSV1_DELIMITER  = ," >> ${inifile}
		echo "CSV1_NODATA     = -999" >> ${inifile}
		echo "CSV1_FIELDS		= " $(head -1 ./download/${stnid}.csv | awk -F, -v what="n" -f parse_fields.awk) >> ${inifile}
		echo "CSV1_UNITS_OFFSET		= " $(head -1 ./download/${stnid}.csv | awk -F, -v what="o" -f parse_fields.awk) >> ${inifile}
		echo "CSV1_UNITS_MULTIPLIER	= " $(head -1 ./download/${stnid}.csv | awk -F, -v what="m" -f parse_fields.awk) >> ${inifile}
	fi
	if (( ${get_live_data} )); then
		echo "[INPUT]" >> ${inifile}
		echo "METEOFILE2 = ${stnid}_live.csv" >> ${inifile}
		echo "POSITION2 = latlon ${latitude} ${longitude} ${altitude}" >> ${inifile}
		echo "CSV2_NAME = ${stnname}" >> ${inifile}
		echo "CSV2_ID = ${stnid}" >> ${inifile}
		echo "CSV2_COLUMNS_HEADERS = 1" >> ${inifile}
		echo "CSV2_DATETIME_SPEC = YYYY-MM-DDTHH24:MI:SSZ" >> ${inifile}
		echo "CSV2_DELIMITER  = ," >> ${inifile}
		echo "CSV2_NODATA     = -999" >> ${inifile}
		echo "CSV2_FIELDS		= " $(head -1 ./download/${stnid}_live.csv | awk -F, -v what="n" -f parse_fields.awk) >> ${inifile}
		echo "CSV2_UNITS_OFFSET		= " $(head -1 ./download/${stnid}_live.csv | awk -F, -v what="o" -f parse_fields.awk) >> ${inifile}
		echo "CSV2_UNITS_MULTIPLIER	= " $(head -1 ./download/${stnid}_live.csv | awk -F, -v what="m" -f parse_fields.awk) >> ${inifile}
		echo "[InputEditing]" >> ${inifile}
		echo "*::edit1 = AUTOMERGE" >> ${inifile}
		if [ -e "./smet/${stnid}.smet" ]; then
			# If a processed smet file exists, create a parameter for each, so we can be sure we can merge (otherwise we get a mismatch on the number of fields)
			fields=$(grep ^fields ./smet/${stnid}.smet | awk -F\= '{print $NF}')
			n=1
			for var in ${fields}
			do
				if [[ ${var} == "timestamp" ]] || [[ ${var} == "TIMESTAMP" ]]; then continue; fi	# timestamp column can be ignored
				let n=${n}+1
				echo "*::edit${n} = CREATE" >> ${inifile}
				echo "*::arg${n}::algorithm = CST" >> ${inifile}
				echo "*::arg${n}::param     = ${var}" >> ${inifile}
				echo "*::arg${n}::value     = -999999" >> ${inifile}	# A fake nodata value, because using the real nodata value doesn't work (it doesn't create the parameter)
			done
		fi
	fi
	if (( ${fullmergeupdate} )); then
		if [ -e "./smet/${stnid}.smet" ]; then
			nodata_val=$(fgrep -m 1 nodata ./smet/${stnid}.smet | awk -F\= '{print 1.*$NF}')
			fgrep -m 1 fields ./smet/${stnid}.smet | awk -F\=\  '{print $NF}' > ./download/${stnid}_existing.csv.tmp
			sed -n '/\[DATA\]/,$p' ./smet/${stnid}.smet | sed '1d' >> ./download/${stnid}_existing.csv.tmp
			echo "[INPUT]" >> ${inifile}
			echo "METEOFILE3 = ${stnid}_existing.csv.tmp" >> ${inifile}
			echo "POSITION3 = latlon ${latitude} ${longitude} ${altitude}" >> ${inifile}
			echo "CSV3_NAME = ${stnname}" >> ${inifile}
			echo "CSV3_ID = ${stnid}" >> ${inifile}
			echo "CSV3_COLUMNS_HEADERS = 1" >> ${inifile}
			echo "CSV3_DATETIME_SPEC = YYYY-MM-DDTHH24:MI:SS" >> ${inifile}
			echo "CSV3_DELIMITER  = SPACE" >> ${inifile}
			echo "CSV3_NODATA     = ${nodata_val}" >> ${inifile}
			echo "CSV3_FIELDS		= " $(head -1 ./download/${stnid}_existing.csv.tmp) >> ${inifile}
			echo "[InputEditing]" >> ${inifile}
			echo "*::edit1 = AUTOMERGE" >> ${inifile}
		else
			echo "[WARNING] ./smet/${stnid}.smet does not exist, cannot do full merge update..."
		fi
	fi
	echo "[OUTPUT]" >> ${inifile}
	echo "COORDSYS = CH1903" >> ${inifile}
	echo "COORDPARAM = NULL" >> ${inifile}
	echo "TIME_ZONE = 0" >> ${inifile}
	echo "METEO = SMET" >> ${inifile}
	echo "METEOPATH = ./smet/" >> ${inifile}
	if (( ${fullmergeupdate} )); then
		echo "SMET_WRITEMODE = OVERWRITE" >> ${inifile}
	else
		echo "SMET_WRITEMODE = APPEND" >> ${inifile}
	fi

	# Run the data extraction
	meteoio_timeseries -c ./download/io.ini -b ${startTime} -e ${endTime} -s 30

	# Obtain some more metadata
	if (( ${make_meta_data_table} )); then
		# Get some more metadata
		curl -f -s -o ./download/verification.json "http://snowpack-config.meassrv.int.slf.ch/verification/"
		# Collecting information for meta data table
		warning_region=$(curl -p -s "https://aws.slf.ch/api/warningregion/sector/findByLocWGS84?lat=${latitude}&lon=${longitude}&date=$(date +"%Y-%m-%d")" | jq '.sector_id' | tr -d '\"')
		if [ -z "${warning_region}" ]; then warning_region="null"; fi
		drift_stnid=$(jq '.[] | select(.station_code == "'${stnid}'") | .config.drift_station_code' ./download/verification.json | tr -d '\"')
		if [ -z "${drift_stnid}" ]; then drift_stnid="null"; fi
		windscaling=$(jq '.[] | select(.station_code == "'${stnid}'") | .config.wind_scaling_factor' ./download/verification.json)
		if [ -z "${windscaling}" ]; then windscaling="1.0"; fi
		slope=$(jq '.[] | select(.station_code == "'${stnid}'") | .config.slope' ./download/verification.json)
		if [ -z "${slope}" ]; then slope="null"; fi
		exp=$(jq '.[] | select(.station_code == "'${stnid}'") | .config.exposition' ./download/verification.json)
		if [ -z "${exp}" ]; then exp="null"; fi
		echo ${stnid} ${latitude} ${longitude} ${altitude} ${type} ${warning_region} ${drift_stnid} ${windscaling} ${slope} ${exp} >> station_meta.txt
	fi

	if (( ${get_live_data} )); then
		# A fake nodata value can have been inserted. Correct those cases.
		sed -i 's/-999999.000/-999/g' ./smet/${stnid}.smet
	fi

	# Cleanup
	rm ./download/io.ini
	if (( ${fullmergeupdate} )); then
		rm ./download/${stnid}_existing.csv.tmp
	fi
done

# Cleanup
rm ./download/stations.csv.mod
