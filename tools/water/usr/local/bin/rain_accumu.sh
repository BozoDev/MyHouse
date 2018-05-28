#!/bin/bash

if [ "A$1" != "A" ]
then
	while [ ${#@} -gt 0 ]
	do
	  case "$1" in
	    -d|--debug)
	      shift
	      DEBUG=$1
	      shift
	      ;;
	    -m|--moisture)
	      shift
	      _moist_run=1
	      ;;
	    *)
	      echo "Usage: ${0} [-d|--debug N]"
	      echo " "
	      echo "-d|--debug N	N is debug level"
	      exit 1
	      ;;
	  esac
	done
fi
DEBUG=${DEBUG:=1}
_moist_run=${_moist_run:=0}

_mqtt_rain_topic_24="sensors/weather/rain24_cm"
_mqtt_rain_topic_1h="sensors/weather/hourRain_cm"
_mqtt_id="gardenpy-rainer"
_mqtt_broker="pi3gate"
_mqtt_options="-C 1"

_rain="$( mosquitto_sub ${_mqtt_options} -h "${_mqtt_broker}" -i "${_mqtt_id}" -t "${_mqtt_rain_topic_24}" )"
_rain=$( echo "scale=0;(${_rain}*100)/1"|bc )
_r_h="$( mosquitto_sub ${_mqtt_options} -h "${_mqtt_broker}" -i "${_mqtt_id}" -t "${_mqtt_rain_topic_1h}" )"
_r_h=$( echo "scale=0;(${_r_h}*100)/1"|bc )
[ $DEBUG -gt 0 ] && echo "DEBUG: Hourly rain: ${_r_h} 24hrs: ${_rain}"
_rain=$(( $_rain - $_r_h ))
[ $DEBUG -gt 0 ] && echo "DEBUG: Rain in mm: $_rain"
echo "$(date +%s ) $_rain" >>/run/rainer.txt

