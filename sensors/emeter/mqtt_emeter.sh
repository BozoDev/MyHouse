#!/bin/bash
DEBUG=${DEBUG:-0}

reader_bin="/usr/local/bin/emeter-reader.py"
mqtt_broker=${mqtt_broker:-"localhost.localdomain"}
mqtt_topic=${mqtt_topic:-"sensors/emeter/watt"}
mqtt_bin="/usr/bin/mosquitto_pub"
mqtt_publish=${mqtt_publish:-1}
rrd_update=${rrd_update:-0}
[ $rrd_update -gt 0 ] && rrd_db=${rrd_db:-"/run/emeter/emeter.rrd"}
_vals[0]=0

while [ ${#@} -gt 0 ]
do
  if [ "A$1" == "A-r" ]
  then
    rrd_update=1
    shift
  elif [ "A$1" == "A-m" ]
  then
    mqtt_publish=0
    shift
  elif [ "A$1" == "A-d" ]
  then
    DEBUG=$2
    shift
    shift
  else
    echo "$0 [-h] [-r] [-m] [-d N]"
    echo ""
    echo "h   this help ;)"
    echo "r   also run rrd-update"
    echo "m   disable MQTT publishing"
    echo "d   set debug-level (can also be set in /etc/defaults/mqtt_emeter as env. DEBUG)"
    exit 1
  fi

done

fillVals() {
  local i=$1
  shift
  for line in $@
  do
    _vals[$i]=$line
    [ $DEBUG -gt 0 ] && echo "DEBUG: Adding $line @ pos $i"
    let i++
  done
}

while true
do
  fillVals 0 "$( $reader_bin -s 6)"
  fillVals 3 "$( $reader_bin -s $(( 0x0102 )) )"
  fillVals 6 "$( $reader_bin -s $(( 0x0c )) )"
  fillVals 9 "$( $reader_bin -s $(( 0x015a )) )"
  if [ $rrd_update -gt 0 ]
  then
    if [ $DEBUG -gt 1 ]
    then
      echo -ne "DEBUG: rrp-update \"N"
      for (( i=0;i<${#_vals[@]};i++ ))
      do
        echo -ne ":${_vals[$i]}"
      done
      echo "\""
    fi
    rrdtool update $rrd_db "N$( for (( i=0;i<${#_vals[@]};i++ ));do echo -ne ":${_vals[$i]}";done)"
  fi
  if [ $mqtt_publish -gt 0 ]
  then
    o=1
    for (( i=6;i<9;i++ ))
    do
      $mqtt_bin -h "$mqtt_broker" -i emeter-updater -t "${mqtt_topic}/L$o" -m ${_vals[i]}
      [ $DEBUG -gt 1 ] && echo "DEBUG: $mqtt_bin -h $mqtt_broker -i emeter-updater -t ${mqtt_topic}/L$o -m ${_vals[i]}"
      let o++
    done
  fi
  sleep 30
done
