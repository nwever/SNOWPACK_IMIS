#!/usr/bin/awk -f
function table(input, w) {
	# Translate IMIS variable names to typical MeteoIO variable names
	# w: what to return: "n": name
	#                    "o": units_offset
	#                    "m": units_multiplier
	if(input=="station_code") {if(w=="n") {return "SKIP"} else if(w=="o") {return 0} else if(w=="m") {return 1}};
	if(input=="measure_date") {if(w=="n") {return "DATETIME"} else if(w=="o") {return 0} else if(w=="m") {return 1}};
	if(input=="hyear") {if(w=="n") {return "SKIP"} else if(w=="o") {return 0} else if(w=="m") {return 1}};
	if(input=="TA_30MIN_MEAN") {if(w=="n") {return "TA"} else if(w=="o") {return 273.15} else if(w=="m") {return 1}};
	if(input=="RH_30MIN_MEAN") {if(w=="n") {return "RH"} else if(w=="o") {return 0} else if(w=="m") {return 0.01}};
	if(input=="VW_30MIN_MEAN") {if(w=="n") {return "VW"} else if(w=="o") {return 0} else if(w=="m") {return 1}};
	if(input=="VW_30MIN_MAX") {if(w=="n") {return "VW_MAX"} else if(w=="o") {return 0} else if(w=="m") {return 1}};
	if(input=="DW_30MIN_MEAN") {if(w=="n") {return "DW"} else if(w=="o") {return 0} else if(w=="m") {return 1}};
	if(input=="DW_30MIN_SD") {if(w=="n") {return "DW_SD"} else if(w=="o") {return 0} else if(w=="m") {return 1}};
	if(input=="HS") {if(w=="n") {return "HS"} else if(w=="o") {return 0} else if(w=="m") {return 0.01}};
	if(input=="TS0_30MIN_MEAN") {if(w=="n") {return "TSG"} else if(w=="o") {return 273.15} else if(w=="m") {return 1}};
	if(input=="TS25_30MIN_MEAN") {if(w=="n") {return "TS1"} else if(w=="o") {return 273.15} else if(w=="m") {return 1}};
	if(input=="TS50_30MIN_MEAN") {if(w=="n") {return "TS2"} else if(w=="o") {return 273.15} else if(w=="m") {return 1}};
	if(input=="TS100_30MIN_MEAN") {if(w=="n") {return "TS3"} else if(w=="o") {return 273.15} else if(w=="m") {return 1}};
	if(input=="RSWR_30MIN_MEAN") {if(w=="n") {return "RSWR"} else if(w=="o") {return 0} else if(w=="m") {return 1}};
	if(input=="TSS_30MIN_MEAN") {if(w=="n") {return "TSS"} else if(w=="o") {return 273.15} else if(w=="m") {return 1}};
	print "[WARNING] Unknown field:", input >> "/dev/stderr"
	return input
}
{
	if (what != "n" && what != "o" && what != "m") {
		print "Provide variable \"what\", using awk -v what=\"char\", with char being \"n\" for name, \"o\" for offset or \"m\" for multiplier." > "/dev/stderr"
		exit
	}
	fields=""
	for(i=1; i<=NF; i++) {
		if(length(fields) == 0) {
			fields=table($i, what)
		} else {
			fields=sprintf("%s %s", fields, table($i, what))
		}
	}
}
END {
	print fields
}
