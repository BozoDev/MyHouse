#/bin/bash

ON=0
OFF=1
duration=1200
switcher="/usr/local/bin/gpio write"
wateringfile="/tmp/watering.tmp"

# sprinklers=(hedge shed garage ship terrace)
[ -f /usr/local/etc/sprinklers.sh ] && . /usr/local/etc/sprinklers.sh
_mqtt_topic_caretaker="caretaker/gardener"
_mqtt_broker="pi3gate"
_mqtt_id="gardenpi-gardener"


if [ "A$1" == "A-c" ]
then
	_amnt=$( /usr/local/bin/rain_calc.sh )
	if [ $_amnt -gt 300 ]
	then
		echo "Exiting due to rain > 30(mm * 10) the past X days..."
		/usr/bin/mosquitto_pub -h "$_mqtt_broker" -i "$_mqtt_id" -t "$_mqtt_topic_caretaker" -m "Didn't water the garden, due to too much rain lately"
		exit 2
	else
		shift
	fi
fi

valve="$1"
function cleaner() {
	echo "Shutting Valve: $1 to $OFF"
	/usr/local/bin/gpio write $1 $OFF
	set -u valve OFF ON
}

trap "{ cleaner $valve; exit 255; }" SIGINT SIGTERM SIGHUP
 
if [ "A$1" == "A" ] || [ $1 -lt 0 ] || [ $1 -gt 4 ]
then
	echo "Usage: $0 [-c] VALVE [duration in seconds]"
	echo " "
	echo " -c	called from cron - check rain past X days"
	echo " "
	echo "	where VALVE is a numeric value between 0 and 4"
	echo " "
	echo " 0 - Bushhose"
	echo " 1 - sprinklers by the shed"
	echo " 2 - garage"
	echo " 3 - Flowers Behring"
	echo " 4 - Torrent"
	echo " duration is optional, default being 20 minutes"
	echo "	(1200 seconds)"
	exit 1
fi
if [ "A$2" != "A" ]
then
	duration=$2
fi
# $switcher $1 $ON && sleep 60 && $switcher $1 $OFF
# sleep 5
for (( i=0;i<5;i++ ))
do
	$switcher $i $OFF
done
sleep 1
date -d "+ 1 hour" +%s >$wateringfile
$switcher $1 $ON 
/usr/bin/mosquitto_pub -h pi3gate.localdomain -i "pi/garden" -m 1 -r -t "sprinklers/${sprinklers[$1]}/state"
sleep 3
/usr/local/bin/water-guard.sh &
sleep $duration
$switcher $1 $OFF
/usr/bin/mosquitto_pub -h pi3gate.localdomain -i "pi/garden" -m 0 -r -t "sprinklers/${sprinklers[$1]}/state"
