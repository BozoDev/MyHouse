#!/bin/bash
##########################
# MQTT Shell Listen & Exec

# labomba-l & labomba-r are dns-resolvable names of the Archt
#  speakers left & right of TV

DEBUG=${DEBUG:-0}

. /usr/local/etc/speakers

p="/run/mqtt_listener/mqtt_speaker_backpipe"
pidfile="/run/mqtt_listener/mqtt_speaker_helper.pid"
clean="$pidfile"
_topic="speakers/+/set_state"
_broker="localhost"
_mqtt_id="pi3gate/speaker-switch"
_mqtt_ops="-v -m 1"

ctrl_c() {
  echo "Cleaning up..."
  pid=$(cat $pidfile)
  rm -f $p;rm "$clean";kill $pid 2>/dev/null
  if [[ "$?" -eq "0" ]];
  then
     echo "Exit success";exit 0
  else
     exit 1
  fi
}

process_speaker(){
  local speaker="$1" _cmd="" _vol=""
  case "$2" in
    off|0|mute) _state=""
      _cmd="mute"
      ;;
    on|1|normal) _state=""
      _cmd="normal"
      ;;
    get|q|query) _cmd="getVolume"
      ;;
    *) _state="$2"
      _cmd="setVolume"
      ;;
  esac
  [ $DEBUG -gt 0 ] && echo "DEBUG: setting state and publishing result"
  for _speaker in labomba-l labomba-r
  do
    _vol="$( /usr/local/bin/Archt.sh -s ${_speaker} ${_cmd} ${_state} )"
    [ "A$_vol" == "A" ] && continue
    mosquitto_pub -h $_broker -t "speakers/${_speaker}/volume" -m "$_vol"
  done
}

listen(){
  ([ ! -p "$p" ]) && mkfifo $p
  (mosquitto_sub -v -h $_broker -t $_topic -i $_mqtt_id >$p 2>/dev/null) &
  echo "$!" > $pidfile
  while read line <$p
  do
    speaker=${line#*/}
    process_speaker "${speaker%/*}" "${line##* }" &
  done
  [ $DEBUG -gt 0 ] && echo -ne "."
}

trap ctrl_c SIGUSR1 SIGHUP SIGINT
while true
do
  listen
  sleep 0.2
done
