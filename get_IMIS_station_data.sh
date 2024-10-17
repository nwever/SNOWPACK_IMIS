stnlst="WFJ2 SLF2"
mkdir -p ./download/

curl -o ./download/stations.csv "https://measurement-data.slf.ch/imis/stations.csv"
for stnid in ${stnlst}
do
	curl -o ./download/${stnid}.csv https://measurement-data.slf.ch/imis/data/by_station/${stnid}.csv
	col_stnid=$(head -1 ./download/stations.csv | awk -F, '{for(i=1; i<=NF; i++) {if($i=="station_code") {print i; exit}}}')
	col_name=$(head -1 ./download/stations.csv | awk -F, '{for(i=1; i<=NF; i++) {if($i=="label") {print i; exit}}}')
	col_lon=$(head -1 ./download/stations.csv | awk -F, '{for(i=1; i<=NF; i++) {if($i=="lon") {print i; exit}}}')
	col_lat=$(head -1 ./download/stations.csv | awk -F, '{for(i=1; i<=NF; i++) {if($i=="lat") {print i; exit}}}')
	col_elev=$(head -1 ./download/stations.csv | awk -F, '{for(i=1; i<=NF; i++) {if($i=="elevation") {print i; exit}}}')

	stnname=$(awk -F, -v c=${col_stnid} -v s="${stnid}" -v r=${col_name} '{if($c==s) {print $r; exit}}' ./download/stations.csv)
	latitude=$(awk -F, -v c=${col_stnid} -v s="${stnid}" -v r=${col_lat} '{if($c==s) {print $r; exit}}' ./download/stations.csv)
	longitude=$(awk -F, -v c=${col_stnid} -v s="${stnid}" -v r=${col_lon} '{if($c==s) {print $r; exit}}' ./download/stations.csv)
	altitude=$(awk -F, -v c=${col_stnid} -v s="${stnid}" -v r=${col_elev} '{if($c==s) {print $r; exit}}' ./download/stations.csv)

	inifile="./download/io.ini"
	echo "[INPUT]" > ${inifile}
	echo "COORDSYS = CH1903" >> ${inifile}
	echo "COORDPARAM = NULL" >> ${inifile}
	echo "TIME_ZONE = 1" >> ${inifile}
	echo "METEO = CSV" >> ${inifile}
	echo "METEOPATH = ./download/" >> ${inifile}
	echo "STATION1 = ${stnid}.csv" >> ${inifile}
	echo "POSITION1 = latlon ${latitude} ${longitude} ${altitude}" >> ${inifile}
	echo "CSV1_NAME = ${stnname}" >> ${inifile}
	echo "CSV1_ID = ${stnid}" >> ${inifile}
	echo "CSV1_COLUMNS_HEADERS = 1" >> ${inifile}
	echo "CSV1_DATETIME_SPEC = YYYY-MM-DD HH24:MI:SS+00:00" >> ${inifile}
	echo "CSV1_DELIMITER  = ," >> ${inifile}
	echo "CSV1_NODATA     = -999" >> ${inifile}
	echo "CSV1_FIELDS	= " $(head -1 ./download/${stnid}.csv | awk -F, -f parse_fields.awk) >> ${inifile}
	echo "[OUTPUT]" >> ${inifile}
	echo "COORDSYS = CH1903" >> ${inifile}
	echo "COORDPARAM = NULL" >> ${inifile}
	echo "TIME_ZONE = 1" >> ${inifile}
	echo "METEO = SMET" >> ${inifile}
	echo "METEOPATH = ./smet/" >> ${inifile}
	
	meteoio_timeseries -c ./download/io.ini -b 1996-01-01 -e NOW
	
	rm ./download/io.ini
done
