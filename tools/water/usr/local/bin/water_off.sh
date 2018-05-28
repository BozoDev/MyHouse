#!/bin/bash

[ -f /usr/local/etc/sprinklers.sh ] && . /usr/local/etc/sprinklers.sh
_def_off=1500
_tmpfle="/tmp/watering.tmp"
_mqtt_bin="/usr/bin/mosquitto_pub"
_mqtt_broker="pi3gate"
_mqtt_topic="sprinklers"
_mqtt_id="gardenpi-water-off"

while :
do
  sleep 100
  _tmestmp="$( head -n 1 $_tmpfle|sed 's/\([0-9]*\)/\1/g' )"
  if [ "A$_tmestmp" == "A" ]
  then
    continue
  else
    if [ $_tmestmp -gt 1439159077 ] && [ $(( $( date +%s ) - $_tmestmp )) -gt $_def_off ]
    then
      echo "" > $_tmpfle
      for (( i=0;i<5;i++ ))
      do
        /usr/local/bin/gpio write $i 1
        $_mqtt_bin -h ${_mqtt_broker} -i ${_mqtt_id} -t "${_mqtt_topic}/${sprinklers[$i]}/state" -m 0
      done
    fi
  fi
done

