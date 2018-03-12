#!/bin/bash
##########################
# MQTT Shell Listen & Exec

DEBUG=${DEBUG:-0}

. /etc/gpio-switches/switches

p="/run/mqtt_listener/mqtt_listener_backpipe"
pidfile="/run/mqtt_listener/mqtt_listener_helper.pid"
clean="$pidfile"
_topic="lights/+/set_state"
# _broker="localhost"
_broker="raspi2"
_mqtt_id="raspi3/light-switch"
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

process_light(){
  light="$1"
  _cmd=""
  case "$2" in
    off|0) state=0
      _cmd="&cmd=off"
      ;;
    on|1) state=1
      _cmd="&cmd=on"
      ;;
    toggle) state=2
      ;;
    *) state="$2"
      ;;
  esac
  for (( i=0;i<${#switches[@]};i++ ))
  do
    [ $DEBUG -gt 0 ] && echo "DEBUG: Checking $light in ${switches[i]}"
    if [ "$light" == "${switches[i]}" ]
    then
      break
    fi
  done
  echo "$( date "+%Y-%m-%d %H:%M-%S" ) rel${i} ${state}"
# if [ $state -eq 1 ]
# then
#   _cmd="&cmd=on"
# elif [ $state -eq 0 ]
# then
#   _cmd="&cmd=off"
# fi
  if [ $i -ge 0 ] && [ $i -lt 25 ]
  then
    [ $DEBUG -gt 0 ] && echo "DEBUG: setting state and publishing result"
    mosquitto_pub -h $_broker -t "lights/${light} light/state" -m $( curl -s "http://localhost/cgi-bin/relswitch.cgi?rel=${i}${_cmd}" )
  else
    [ $DEBUG -gt 0 ] && echo "DEBUG: Unknown relais requested"
  fi
}

listen(){
  ([ ! -p "$p" ]) && mkfifo $p
  (mosquitto_sub -v -h $_broker -t $_topic -i $_mqtt_id >$p 2>/dev/null) &
  echo "$!" > $pidfile
  while read line <$p
  do
    light="${line%% *}"
    # light="${light#*/}"
    # state="${line##* }"
# We'll shove this as async, so that we don't miss any publishing...
    process_light "${light#*/}" "${line##* }" &
  done
  [ $DEBUG -gt 0 ] && echo -ne "."
}

trap ctrl_c SIGUSR1 SIGHUP SIGINT
while true
do
  listen
  sleep 0.2
done

