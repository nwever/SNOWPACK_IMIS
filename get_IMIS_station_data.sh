stnlst="WFJ2 SLF2"	# Leave empty to download all available stations listed in stations.csv
make_meta_data_table=0

mkdir -p ./download/

if (( ${make_meta_data_table} )); then
	echo "#station_code lat lon elevation type warning_region drift_station_code wind_scaling_factor slope exposition" > station_meta.txt
fi

# Get the station list
curl -s -C  - -o ./download/stations.csv "https://measurement-data.slf.ch/imis/stations.csv"
sed -E 's/"([^"]*), ([^"]*)"/"\1__\2"/g' ./download/stations.csv > ./download/stations.csv.mod
# Get some more metadata
curl -f -s -C  - -o ./download/verification.json "http://snowpack-config.meassrv.int.slf.ch/verification/"

col_stnid=$(head -1 ./download/stations.csv.mod | awk -F, '{for(i=1; i<=NF; i++) {if($i=="station_code") {print i; exit}}}')
col_name=$(head -1 ./download/stations.csv.mod | awk -F, '{for(i=1; i<=NF; i++) {if($i=="label") {print i; exit}}}')
col_lon=$(head -1 ./download/stations.csv.mod | awk -F, '{for(i=1; i<=NF; i++) {if($i=="lon") {print i; exit}}}')
col_lat=$(head -1 ./download/stations.csv.mod | awk -F, '{for(i=1; i<=NF; i++) {if($i=="lat") {print i; exit}}}')
col_elev=$(head -1 ./download/stations.csv.mod | awk -F, '{for(i=1; i<=NF; i++) {if($i=="elevation") {print i; exit}}}')
col_type=$(head -1 ./download/stations.csv.mod | awk -F, '{for(i=1; i<=NF; i++) {if($i=="type") {print i; exit}}}')

if [ -z "${stnlst}" ]; then
	stnlst=$(awk -F, -v c=${col_stnid} '(NR>1) {if(NR>2) {printf " "}; printf "%s", $c}' ./download/stations.csv.mod)
fi

for stnid in ${stnlst}
do
	curl -f -s -C  - -o ./download/${stnid}.csv https://measurement-data.slf.ch/imis/data/by_station/${stnid}.csv
	if [ ! -e "./download/${stnid}.csv" ]; then
		echo "Downloading ${stnid}.csv failed..."
		continue
	fi

	stnname=$(  awk -F, -v c=${col_stnid} -v s="${stnid}" -v r=${col_name} '{if($c==s) {print $r; exit}}' ./download/stations.csv.mod | sed 's/__/, /g' | tr -d '\"')
	latitude=$( awk -F, -v c=${col_stnid} -v s="${stnid}" -v r=${col_lat}  '{if($c==s) {print $r; exit}}' ./download/stations.csv.mod)
	longitude=$(awk -F, -v c=${col_stnid} -v s="${stnid}" -v r=${col_lon}  '{if($c==s) {print $r; exit}}' ./download/stations.csv.mod)
	altitude=$( awk -F, -v c=${col_stnid} -v s="${stnid}" -v r=${col_elev} '{if($c==s) {print $r; exit}}' ./download/stations.csv.mod)
	type=$(     awk -F, -v c=${col_stnid} -v s="${stnid}" -v r=${col_type} '{if($c==s) {print $r; exit}}' ./download/stations.csv.mod)

	col_date=$(head -1 ./download/${stnid}.csv | awk -F, '{for(i=1; i<=NF; i++) {if($i=="measure_date") {print i; exit}}}')
	if [ "${stnid}" == "WFJ2" ]; then
		startTime="1999-08-04T11:00:00"
	else
		startTime=$(awk -F, -v r=${col_date} '(NR==2) {print substr($r,1,10) "T" substr($r,12,8); exit}' ./download/${stnid}.csv)
	fi
	endTime=$(tail -1 ./download/${stnid}.csv | awk -F, -v r=${col_date} '{print substr($r,1,10) "T" substr($r,12,8); exit}')

	inifile="./download/io.ini"
	echo "[INPUT]" > ${inifile}
	echo "COORDSYS = CH1903" >> ${inifile}
	echo "COORDPARAM = NULL" >> ${inifile}
	echo "TIME_ZONE = 0" >> ${inifile}
	echo "METEO = CSV" >> ${inifile}
	echo "METEOPATH = ./download/" >> ${inifile}
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
	echo "[OUTPUT]" >> ${inifile}
	echo "COORDSYS = CH1903" >> ${inifile}
	echo "COORDPARAM = NULL" >> ${inifile}
	echo "TIME_ZONE = 0" >> ${inifile}
	echo "METEO = SMET" >> ${inifile}
	echo "METEOPATH = ./smet/" >> ${inifile}

	meteoio_timeseries -c ./download/io.ini -b ${startTime} -e ${endTime} -s 30

	# Obtain some more metadata
	if (( ${make_meta_data_table} )); then
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

	rm ./download/io.ini
done

rm ./download/stations.csv.mod
