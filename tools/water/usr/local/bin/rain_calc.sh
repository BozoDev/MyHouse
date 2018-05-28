#!/bin/bash

DEBUG=0

_days=3
_now=$( date +%s )

while read -r line
do
	_t=${line% *}
	_v=${line#* }
	if [ "A$_t" != "A" ] && [ $(( $_now - $_t )) -lt $(( $_days*24*60*60 + 30 )) ]
	then
		let amnt+=_v
		_vals="$( [ "A$_vals" != "A" ] && echo "$_vals"; echo "$_t $_v" )"
	else
		continue
	fi
	[ $DEBUG -gt 1 ] && echo "DEBUG: @ $_t val: $_v"
done </run/rainer.txt 
echo "$_vals" >/run/rainer.txt
[ $DEBUG -gt 0 ] && echo "DEBUG: overall rain past $_days days: $amnt"
echo "$amnt"

