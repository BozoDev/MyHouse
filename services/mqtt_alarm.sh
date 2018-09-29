#!/bin/bash
##########################
# MQTT Shell Listen & Trigger Alarms
#
# 3 arrays:
# _topics     MQTT-subscriptions to monitor
# _thresholds Trigger alarm when received value > value mentioned here
# _msgs       Message to send with alarm

DEBUG=${DEBUG:-0}

p="/run/mqtt_listener/mqtt_listener_alarm_backpipe"
pidfile="/run/mqtt_listener/mqtt_listener_alarm_helper"
clean="$pidfile"
_topics=( "sensors/weather/windGust_kph" "sensors/+/CPULoad/15" )
_thresholds=( 36 80 )
_alerts=( "wind-gust-alarm" "high-cpu-load-15" )
_msgs=( "Windgust in km/h - Check trampolin and windows" "High 15-mintues CPU-Load - login and check" )
# _broker="localhost"
_mqtt_broker="pi3gate"
_mqtt_id="pi3gate/mqtt-alerter"
# _mqtt_ops="-v -R"
_mqtt_ops="-R"
_mqtt_topic="caretaker/"

ctrl_c() {
  local e=0
  echo "Cleaning up..."
  for (( i=0;i<${#_alerts[@]};i++))
  do
    pid=$(cat "${pidfile}-${_alerts[$i]}.pid")
    rm -f "${p}-${_alerts[$i]}";rm "${clean}-${_alerts[$i]}.pid";kill $pid 2>err.txt
    _r=$?
    if [[ "$_r" -eq "0" ]];
    then
      [ $DEBUG -gt 0 ] && echo "Exit ${_alerts[$i]}  success"
    else
      [ $DEBUG -gt 0 ] && echo "Exit ${_alerts[$i]} failed: $_r - $( cat err.txt )"
      let e++
    fi
  done
  rm err.txt >/dev/null 2>&1
  exit $e
}

process_message(){
  local _alerter="$1"
  shift
  local _msg="$@"
  local _cmd="mosquitto_pub -h ${_mqtt_broker} -i ${_mqtt_id} -t \"${_mqtt_topic}${_alerter}\" -m \"${_msg}\""
  local _r="$( echo "$_cmd"|sh )"
  echo $_r
}

listen(){
  local _alert="${_alerts[$1]}" _threshold="${_thresholds[$1]}" _topic="${_topics[$1]}" _msg="${_msgs[$1]}"
  local _pipe="${p}-${_alert}" _pidfile="${pidfile}-${_alert}.pid" _id="${_mqtt_id}-${_alert}" line="" _val=0
  ([ ! -p "$_pipe" ]) && mkfifo $_pipe
  (mosquitto_sub $_mqtt_ops -h $_mqtt_broker -t $_topic -i $_id >$_pipe 2>/dev/null) &
  echo "$!" > $_pidfile
  while read line <${_pipe}; _r=$?; (( ! $_r ))
  do
    _val=${line%.*}
    [ $DEBUG -gt 0 ] && echo "DEBUG: Throshold: $_threshold and read(calc'd): $_val"
    if [ $_threshold -lt $_val ]
    then
      mosquitto_pub -h $_mqtt_broker -i $_mqtt_id -t "${_mqtt_topic}/${_alert}" -m "Warning - $_alert measured $_val exceeding $_threshold - ${_msg}"
      [ $DEBUG -gt 0 ] && echo "DEBUG: read line $line"
    else
      [ $DEBUG -gt 0 ] && echo "DEBUG: read line \"$line\" - didn't exceed $_threshold"
    fi
  done
  echo "Returned: $_r in ${_alert}"
  if [ $_r -eq 130 ]
  then
    echo "CTRL-C (SIG-INT) detected in ${_alert}"
    sleep 1
    exit 0
  fi
  if [ "A${line}" == "A" ]
  then
    process_message ${_alert} "timeout reached"
    if [ -f "${_pidfile}" ]
    then
      _pid=$( cat "${_pidfile}" )
      kill $_pid && rm "${_pidfile}"
    fi
  fi
  [ $DEBUG -gt 0 ] && echo -ne "."
}

trap ctrl_c SIGUSR1 SIGHUP SIGINT
for (( i=0;i<${#_alerts[@]};i++ ))
do
  echo "Starting alerter ${_alerts[$i]} with threshold of ${_thresholds[$i]} on topic ${_topics[$i]}"
  ( listen "${i}" ) &
done

sleep 5

while true
do
  for (( i=0;i<${#_alerts[@]};i++ ))
  do
    _pidf="${pidfile}-${_alerts[$i]}.pid"
    if [ ! -f ${_pidf} ]
    then
      echo "Missing ${_pidf} - restarting ${alerts[$i]}"
      ( listen "${_alerts[$i]}" "${_timeouts[$i]}" "${_topics[$i]}" ) &
    elif ! ls /proc/$( cat ${_pidf} )/exe >/dev/null
    then
      echo "PID-File $_pidf points to dead process"
      rm $_pidf
      ( listen "${_alerts[$i]}" "${_timeouts[$i]}" "${_topics[$i]}" ) &
    fi
  done
  sleep 90
done

