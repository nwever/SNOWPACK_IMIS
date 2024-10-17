soil=0

# Create required directories
mkdir -p ./input/
mkdir -p ./cfgfiles/
mkdir -p ./current_snow/
mkdir -p ./output/
mkdir -p ./log/

# Create *sno file
function WriteSnoFile {
	echo "SMET 1.1 ASCII" > ${snofile}
	echo "[HEADER]" >> ${snofile}
	echo "station_id = ${stnid}" >> ${snofile}
	echo "station_name = ${stnname}" >> ${snofile}
	echo "latitude     = ${latitude}" >> ${snofile}
	echo "longitude    = ${longitude}" >> ${snofile}
	echo "altitude = ${altitude}" >> ${snofile}
	echo "nodata = -999" >> ${snofile}
	echo "tz = 0" >> ${snofile}
	echo "ProfileDate = ${profiledate}" >> ${snofile}
	echo "HS_Last = 0.0" >> ${snofile}
	echo "SlopeAngle = ${SlopeAngle}" >> ${snofile}
	echo "SlopeAzi = ${SlopeAzi}" >> ${snofile}
	if (( ${soil} )); then
		echo "nSoilLayerData = 6" >> ${snofile}
	else
		echo "nSoilLayerData = 0" >> ${snofile}
	fi
	echo "nSnowLayerData = 0" >> ${snofile}
	echo "SoilAlbedo = 0.2" >> ${snofile}
	echo "BareSoil_z0 = 0.02" >> ${snofile}
	echo "CanopyHeight = 0" >> ${snofile}
	echo "CanopyLeafAreaIndex = 0" >> ${snofile}
	echo "CanopyDirectThroughfall = 1" >> ${snofile}
	echo "WindScalingFactor = 0" >> ${snofile}
	echo "ErosionLevel = 0" >> ${snofile}
	echo "TimeCountDeltaHS = 0" >> ${snofile}
	echo "fields = timestamp Layer_Thick T Vol_Frac_I Vol_Frac_W Vol_Frac_V Vol_Frac_S Rho_S Conduc_S HeatCapac_S rg rb dd sp mk mass_hoar ne CDot metamo" >> ${snofile}
	echo "[DATA]" >> ${snofile}
	if (( ${soil} )); then
		echo "1980-10-01T01:00 1.0 281.15 0 0.25 0.125 0.625 2700 2.5 871 7.5 0 0 0 0 0 4 0 0" >> ${snofile}
		echo "1980-10-01T01:00 1.0 281.15 0 0.25 0.125 0.625 2700 2.5 871 7.5 0 0 0 0 0 5 0 0" >> ${snofile}
		echo "1980-10-01T01:00 0.6 281.15 0 0.25 0.125 0.625 2700 2.5 871 7.5 0 0 0 0 0 4 0 0" >> ${snofile}
		echo "1980-10-01T01:00 0.3 281.15 0 0.25 0.125 0.625 2700 2.5 871 7.5 0 0 0 0 0 3 0 0" >> ${snofile}
		echo "1980-10-01T01:00 0.1 281.15 0 0.25 0.125 0.625 2700 2.5 871 7.5 0 0 0 0 0 2 0 0" >> ${snofile}
		echo "1980-10-01T01:00 0.1 281.15 0 0.25 0.125 0.625 2700 2.5 871 7.5 0 0 0 0 0 5 0 0" >> ${snofile}
	fi
}

# Create ini file
function WriteIniFile {
	echo "IMPORT_BEFORE		= ./io_base.ini" > ${inifile}
	echo "[INPUT]" >> ${inifile}
	echo "STATION1			= ${stnid}" >> ${inifile}
	if (( ${soil} )); then
		echo "[SNOWPACK]" >> ${inifile}
		echo "SNP_SOIL = TRUE" >> ${inifile}
		echo "SOIL_FLUX = TRUE" >> ${inifile}
	fi
}

for smetfile in ./smet/*
do
	stnid=$(grep -m1 station_id ${smetfile} | awk -F= '{gsub(/^[ \t]+/,"", $NF); print $NF}')
	echo Preparing SNOWPACK setup for: ${stnid}
	inifile="./cfgfiles/io_${stnid}.ini"
	logfile="./log/${stnid}.log"

	stnname=$(grep -m1 station_name ${smetfile} | awk -F= '{gsub(/^[ \t]+/,"", $NF); print $NF}')
	latitude=$(grep -m1 latitude ${smetfile} | awk -F= '{gsub(/^[ \t]+/,"", $NF); print $NF}')
	longitude=$(grep -m1 longitude ${smetfile} | awk -F= '{gsub(/^[ \t]+/,"", $NF); print $NF}')
	altitude=$(grep -m1 altitude ${smetfile} | awk -F= '{gsub(/^[ \t]+/,"", $NF); print $NF}')
	profiledate=$(awk '{if(/\[DATA\]/) {getline; gsub(/^[ \t]+/,"", $1); print $1; exit}}' ${smetfile})

	# Flat field
	SlopeAngle=0
	SlopeAzi=0
	snofile="./input/${stnid}.sno"
	WriteSnoFile
	# Virtual slopes
	SlopeAngle=38
	for vs in $(seq 1 4)
	do
		SlopeAzi=$(echo "(${vs}-1)*90" | bc)
		snofile="./input/${stnid}${vs}.sno"
		WriteSnoFile
	done
	WriteIniFile
done
