#/bin/bash
###
# Calcs:
#  Ter-Spr: ca. 20m^2 - 1" high uses 500l at 5.8l/min takes 86min per week
#  Shed: ca. 20m^2 - 1" high uses 500l at 7l/min takes 71minutes
#  Ship: ca. 6m^2 - 1" high uses 144l at 6.9l/min takes 20min
#  Gara: ca 12m^2 - 1" high uses unknown
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
_mqtt_bin_pub="/usr/bin/mosquitto_pub"
_mqtt_bin_sub="/usr/bin/mosquitto_sub"

if [ "A$1" == "A-c" ]
then
	_amnt=$( /usr/local/bin/rain_calc.sh )
        _skipWatering=0
        _careMessage="Didn't water the garden, due to: "
	if [ $_amnt -gt 300 ]
	then
		echo "Exiting due to rain > 30(mm * 10) the past X days..."
		_careMessage="$_careMessage too much rain in the past 3 days"
		let _skipWatering++
	fi
        _amnt=$( $_mqtt_bin_sub -h "$_mqtt_broker" -i "$_mqtt_id" -t "sensors/weather/hourRain_cm" )
        if [ $_amnt -gt 30 ]
        then
          echo "Exiting due to rain past 1hr > 3(mm * 10)...."
          _careMessage="$_careMessage too much rain in the past 1hr"
          let _skipWatering++
        fi
        _amnt=$( $_mqtt_bin_sub -h "$_mqtt_broker" -i "$_mqtt_id" -t "sensors/weather/rain_cm" )
        if [ $_amnt -gt 0 ]
        then
          echo "Exiting due to raining..."
          _careMessage="$_careMessage it's $( date ) and currently raining"
          let _skipWatering++
          $_mqtt_bin_pub  -h "$_mqtt_broker" -i "$_mqtt_id" -t "$_mqtt_topic_caretaker" -m "Sleeping 12hrs and re-running"
          sleep $(( 12*3600 ))
          /usr/local/bin/water.sh ${@}
        fi
        [ $_skipWatering -gt 0 ] && $_mqtt_bin_pub  -h "$_mqtt_broker" -i "$_mqtt_id" -t "$_mqtt_topic_caretaker" -m "$_careMessage RainCondition counter: $_skipWatering" && exit 2
        shift
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
