#!/bin/bash
##########################
# MQTT Shell Listen & Exec

DEBUG=${DEBUG:-0}

. /usr/local/etc/speakers

p="/run/mqtt_listener/mqtt_speaker_backpipe"
pidfile="/run/mqtt_listener/mqtt_speaker_helper.pid"
clean="$pidfile"
_topic="speakers/+/set_state"
# _broker="localhost"
_broker="pi3gate"
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
  # for (( i=0;i<${#speakers[@]};i++ ))
  # do
  #   [ $DEBUG -gt 0 ] && echo "DEBUG: Checking $speaker in ${speakers[i]}"
  #   if [ "$speaker" == "${speakers[i]}" ]
  #   then
  #     break
  #   fi
  # done
  # if [ $i -ge 0 ] && [ $i -lt 5 ]
  # then
  [ $DEBUG -gt 0 ] && echo "DEBUG: setting state and publishing result"
  for _speaker in labomba-l labomba-r
  do
    _vol="$( /usr/local/bin/Archt.sh -s ${_speaker} ${_cmd} ${_state} )"
    [ "A$_vol" == "A" ] && continue
    mosquitto_pub -h $_broker -t "speakers/${_speaker}/volume" -m "$_vol"
  done
  # else
  #   [ $DEBUG -gt 0 ] && echo "DEBUG: Unknown speaker requested"
  # fi
}

listen(){
  # local last_msg=$( date +%s )
  ([ ! -p "$p" ]) && mkfifo $p
  (mosquitto_sub -v -h $_broker -t $_topic -i $_mqtt_id >$p 2>/dev/null) &
  echo "$!" > $pidfile
  while read line <$p
  do
    speaker=${line#*/}
# Sometimes we need a break, re-enable if rapid re-fire
    # if [ $(( $( date +%s ) - $last_msg )) -gt 1 ]
    # then
    # # We'll shove this as async, so that we don't miss any publishing...
    process_speaker "${speaker%/*}" "${line##* }" &
    #   last_msg=$( date +%s )
    # fi
  done
  [ $DEBUG -gt 0 ] && echo -ne "."
}

trap ctrl_c SIGUSR1 SIGHUP SIGINT
while true
do
  listen
  sleep 0.2
done

