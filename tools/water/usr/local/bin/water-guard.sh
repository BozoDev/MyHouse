#!/bin/bash
DEBUG=0

[ -f /usr/local/etc/sprinklers.sh ] && . /usr/local/etc/sprinklers.sh || exit 1
# Let's give the thing a minute to blow out air & get running properly
sleep 60

_mqtt_bin="/usr/bin/mosquitto_pub"
_mqtt_broker="pi3gate.localdomain"
_mqtt_id="sprinkler-flowrate"
_mqtt_topic="caretaker/flowrate"
_flowr_bin="/usr/local/bin/flowrate.sh"
_waterfile="/tmp/watering.tmp"
_spk=""
_wc=0
_ec=0

function which_sprinkler() {
  for ((i=0;i<${#sprinklers[@]};i++))
  do
    [ $( /usr/local/bin/gpio read $i ) -eq 0 ] && break
    [ $DEBUG -gt 1 ] && >&2 echo "DEBUG: Sprinkler ${sprinklers[$i]} not on"
  done
  [ $DEBUG -gt 2 ] && >&2 echo "DEBUG: i=$i"
  [ $i -eq ${#sprinklers[@]} ] && [ $( /usr/local/bin/gpio read $i ) -eq 1 ] && return 1
  echo $i
}

#  Avr water consumption:
#   ship 6.8-6.99
#   hedge 4.5
#   shed  7
#   Ter   5.8
_spk=$( which_sprinkler )
[ $DEBUG -gt 0 ] && echo "DEBUG: Sprinkler: $_spk"
[ "A$_spk" == "A" ] && exit 1 

while [ "A$( cat $_waterfile )" != "A" ]
do
  [ $( /usr/local/bin/gpio read $_spk ) -eq 1 ] && exit 1
  _wc=$( echo "scale=0;($( $_flowr_bin -i 5 )*10)/1"|bc )
  if [ $_wc -lt $(( ${consumption[$_spk]} - 2 )) ] || [ $_wc -gt $(( ${consumption[$_spk]} + 2 )) ]
  then
    [ $DEBUG -gt 0 ] && echo "DEBUG: Flowrate for ${sprinklers[$_spk]} sprinkler abnormal - should be ${consumption[$_spk]} - measured $_wc"
    let _ec++
  else
    [ $DEBUG -gt 1 ] && echo "DEBUG: Flowrate for ${sprinklers[$_spk]} sprinkler tolerated @ $_wc"
    [ $_ec -gt 0 ] && let _ec--
  fi
  sleep 60
  if [ $_ec -gt 2 ]
  then
    [ $DEBUG -gt 0 ] && echo "DEBUG: Error-counter >2 - will trigger alarm"
    ${_mqtt_bin} -i "${_mqtt_id}" -h "${_mqtt_broker}" -t "${_mqtt_topic}" -m "Flowrate for ${sprinklers[$_spk]} abnormal - should be $( echo "scale=1;${consumption[$_spk]}/10"|bc ) l per minute - measured $( echo "scale=1;$_wc/10"|bc )"
    _ec=0
  fi
done

