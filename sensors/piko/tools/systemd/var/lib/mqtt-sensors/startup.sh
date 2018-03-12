#!/bin/bash
dirs="mqtt_publisher emeter solar"

for dir in $dirs
do
  [ -d "/run/${dir}" ] || mkdir -p "/run/${dir}" 2>/dev/null
  chown mqtt-service "/run/${dir}"
done
