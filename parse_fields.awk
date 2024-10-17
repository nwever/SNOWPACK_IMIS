#!/usr/bin/awk -f
function table(input) {
	# Translate SNOTEL variable names to typical MeteoIO variable names
	if(input=="station_code") {return "SKIP"};
	if(input=="measure_date") {return "DATETIME"};
	if(input=="hyear") {return "SKIP"};
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

