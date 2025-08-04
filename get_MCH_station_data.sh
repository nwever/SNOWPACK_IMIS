# Download MCH stations required to run SNOWPACK
# Requires DBO plugin, only works from within SLF network

fullpath_meteoio_timeseries=$(which meteoio_timeseries)
if [[ -z "${fullpath_meteoio_timeseries}" ]]; then
	echo "ERROR: cannot find meteoio_timeseries binary. Make sure \$PATH is set correctly to contain a path to the meteoio_timeseries binary." >&2
	exit 1
fi

# Construct ini file
inifile="io_mch.ini"
echo "BUFFER_SIZE = 370" > ${inifile}
echo "BUFF_BEFORE = 1.5" >> ${inifile}
echo "[InputEditing]" >> ${inifile}
echo "*::edit1 = AUTOMERGE" >> ${inifile}
echo "[Output]" >> ${inifile}
echo "METEO = SMET" >> ${inifile}
echo "METEOPATH = ./smet/" >> ${inifile}
echo "[Input]" >> ${inifile}
echo "COORDSYS = CH1903" >> ${inifile}
echo "TIME_ZONE = 0" >> ${inifile}
echo "METEO = DBO" >> ${inifile}

n=0
for stn in "*ATT1" "*CMA1" "*DIA1" "*EGH1" "*GOR1" "*MTR1" "*NAS1" "*WFJ1" "*PMA1" "*TIT1" "*WFJ1"
do
	let n=${n}+1
	echo "METEOFILE${n} = SMN::${stn}" >> ${inifile}
done

# Determine first and last time stamps in the smet files
startTime=$(for f in smet/*; do awk '{if(/\[DATA\]/) {getline; print $1; exit}}' ${f}; done | sort -nk1 | head -1)
endTime=$(for f in smet/*; do tac ${f} | awk '{print $1; exit}'; done | sort -nrk1 | head -1)

# Use meteoio_timeseries to obtain the data
echo "Getting data from ${startTime} to ${endTime}..."
${fullpath_meteoio_timeseries} -c ${inifile} -b ${startTime} -e ${endTime} -s 30

rm ${inifile}
