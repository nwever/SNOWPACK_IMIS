#!/bin/bash
for f in ./log/*.log
do

	[ -f "$f" ] || continue

	# Get the last non-empty line
	status=$(grep -P '[^\s]' ${f} | tail -n 1)

	if [[ "${status}" =~ ^[[:space:]]*FINISHED\ running ]]; then
		echo "$(basename "${f}"): OK"
	else
		echo "$(basename "${f}"): Fail"
		tail -20 ${f}
	fi
done

