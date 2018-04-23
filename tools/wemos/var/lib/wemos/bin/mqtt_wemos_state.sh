#!/bin/bash
##########################
# MQTT Shell Listen & Trigger update

DEBUG=1

. /var/lib/wemos/lib/switches.sh

p="/run/wemos/mqtt_update_backpipe"
pidfile="/run/wemos/mqtt_update_listener.pid"
mpid="/run/wemos/mqtt_update.pid"
clean="$pidfile"
_topic="+/+/state"
_broker="pi2gate.localdomain"
_mqtt_id="pigate/wemos-updater"
_mqtt_ops="-v -R -i $_mqtt_id"
[ -f /run/wemos/wemos.pid ] && WEMOSPID="/run/wemos/wemos.pid"

ctrl_c() {
  echo "DEBUG MQTT-Updater[$$] $( date +%Y%m%d%H%M%S ) Cleaning up updater..."
  pid=$(cat $pidfile)
  rm -f $p;rm "$clean";kill $pid 2>/dev/null
  if [[ "$?" -eq "0" ]];
  then
     [ $DEBUG -gt 0 ] && echo "Exit success"
     rm $mpid
     exit 0
  else
     exit 1
  fi
  exit 0
}

listen(){
  ([ ! -p "$p" ]) && mkfifo $p
  (mosquitto_sub $_mqtt_ops -h $_broker -t $_topic >$p 2>/dev/null) &
  echo "$!" > $pidfile
  noti=0
  while read line <$p
  do
    light="${line%% *}"
    light="${light#*/}"
    state="${line##* }"
    for (( i=0;i<${#switches[@]};i++ ))
    do
      [ $DEBUG -gt 1 ] && echo "DEBUG MQTT-Updater[$$] $( date +%Y%m%d%H%M%S ): Checking $light in ${switches[i]}"
      if [ "$light" == "${switches[i]}" ]
      then
        noti=1
        break
      fi
    done
    if [ $i -eq ${#switches[@]} ]
    then
      if ${line%%sprinklers*} 2>/dev/null
      then
        [ $DEBUG -gt 0 ] && echo "DEBUG MQTT-Updater[$$] $( date +%Y%m%d%H%M%S ): Sprinkler change detected"
        noti=1
      else
        [ $DEBUG -gt 0 ] && echo "DEBUG MQTT-Updater[$$] $( date +%Y%m%d%H%M%S ): unknown Line: $line"
# Not found - lets get out...
        continue
      fi
    fi
    [ $DEBUG -gt 0 ] && echo "DEBUG MQTT-Updater[$$] $( date +%Y%m%d%H%M%S ):rel${i} ${state}"
    if [ $state -gt 0 ]
    then
      _cmd="on"
    else
      _cmd="off"
    fi
    [ -f /run/wemos/wemos.pid ] && WEMOSPID="/run/wemos/wemos.pid" || WEMOSPID=""
    if [ "A$WEMOSPID" != "A" ]
    then
      [ $DEBUG -gt 0 ] && echo "DEBUG MQTT-Updater[$$] $( date +%Y%m%d%H%M%S ): Notifying"
      kill -USR1 $( cat $WEMOSPID )
      read -t 2 line <$p && [ $DEBUG -gt 0 ] && echo "DEBUG MQTT-Updater[$$] $( date +%Y%m%d%H%M%S ): Swallowed $line"
    fi
  done
  if [ $noti -gt 0 ]
  then
    [ -f /run/wemos/wemos.pid ] && WEMOSPID="/run/wemos/wemos.pid" || WEMOSPID=""
    if [ "A$WEMOSPID" != "A" ]
    then
      [ $DEBUG -gt 0 ] && echo "DEBUG MQTT-Updater[$$] $( date +%Y%m%d%H%M%S ): Notifying"
      kill -USR1 $( cat $WEMOSPID )
    fi
    noti=0
  fi
  [ $DEBUG -gt 0 ] && echo "Ping[$$]"
}

trap ctrl_c SIGUSR1

while true
do
  listen
  sleep 0.5
done

