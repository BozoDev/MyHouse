#!/bin/bash
# Should (hopefully) return l/min on water flowing through the system
#
# Note: docs I found on similar flow-meters, use a divisor of 7.5, instead of 5.75
# ToDo: Check if there's a leak, indicating original divisor was actually (more) acurate
#  
#  Avr water consumption:
#   ship 6.8-6.99
#   hedge 4.5
#   shed  7
#   Ter   5.8
DEBUG=0

_pulse_bin="/usr/local/sbin/pulse-measure"
_values=()
c=0
if [ "A$1" == "A-i" ]
then
  _interval=$2
  shift
  shift
fi
_interval=${_interval:-1}

_values=($( $_pulse_bin $_interval ))
[ ${#_values[@]} -eq 0 ] && echo "0.0" && exit 1

for ((i=0;i<${#_values[@]};i++))
do
  [ $DEBUG -gt 0 ] && echo "Value ${_values[$i]} added to $c"
  c="$( echo "${_values[$i]} + $c"|bc )"
done
echo "scale=4;(1/($c/${#_values[@]}))/5.75"|bc
