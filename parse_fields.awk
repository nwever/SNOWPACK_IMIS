#!/usr/bin/awk -f
function table(input) {
	# Translate IMIS variable names to typical MeteoIO variable names
	if(input=="station_code") {return "SKIP"};
	if(input=="measure_date") {return "DATETIME"};
	if(input=="hyear") {return "SKIP"};
	if(input=="TA_30MIN_MEAN") {return "TA"};
	if(input=="RH_30MIN_MEAN") {return "RH"};
	if(input=="VW_30MIN_MEAN") {return "VW"};
	if(input=="VW_30MIN_MAX") {return "VW_MAX"};
	if(input=="DW_30MIN_MEAN") {return "DW"};
	if(input=="DW_30MIN_SD") {return "DW_SD"};
	if(input=="HS") {return "HS"};
	if(input=="TS0_30MIN_MEAN") {return "TSG"};
	if(input=="TS25_30MIN_MEAN") {return "TS1"};
	if(input=="TS50_30MIN_MEAN") {return "TS2"};
	if(input=="TS100_30MIN_MEAN") {return "TS3"};
	if(input=="RSWR_30MIN_MEAN") {return "RSWR"};
	if(input=="TSS_30MIN_MEAN") {return "TSS"};
	print "[WARNING] Unknown field:", input >> "/dev/stderr"
	return input
}
{
	fields=""
	for(i=1; i<=NF; i++) {
		if(length(fields) == 0) {
			fields=table($i)
		} else {
			fields=sprintf("%s %s", fields, table($i))
		}
	}
}
END {
	print fields
}
