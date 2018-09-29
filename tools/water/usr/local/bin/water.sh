#/bin/bash
###
# Calcs:
#  Ter-Spr: ca. 20m^2 - 1" high uses 500l at 8l/min takes 62min per week
#  Ter2: ca. 18m^2 - 1" high uses 432l at 5.7l/min takes 76min
#  Shed: ca. 20m^2 - 1" high uses 500l at 9.7/min takes 52minutes
#  Ship: ca. 6m^2 - 1" high uses 144l at 8.9l/min takes 16min
#  Gara: ca 12m^2 - 1" high uses 288l at 10.5l/min takes 27min

# Current relais-card is active-low - meaning a low on outpin
#  switches relais on
ON=0
OFF=1
# duration=1200
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
        _careMessage="Didn't turn on $2 sprinkler, due to: "
	if [ $_amnt -gt 140 ]
	then
		echo "Exiting due to rain > 20(mm * 10) the past X days..."
		_careMessage="$_careMessage too much rain in the past 3 days"
		let _skipWatering++
	fi
        _amnt=$( echo "scale=0;( $( $_mqtt_bin_sub -C 1 -h "$_mqtt_broker" -i "$_mqtt_id" -t "sensors/weather/hourRain_cm" ) *10)/1"|bc )
        if [ $_amnt -gt 12 ]
        then
          echo "Exiting due to rain past 1hr > 12mm...."
          _careMessage="$_careMessage too much rain in the past 1hr"
          let _skipWatering++
        fi
        _amnt=$( echo "scale=0;( $( $_mqtt_bin_sub -C 1 -h "$_mqtt_broker" -i "$_mqtt_id" -t "sensors/weather/rain24_cm" )*10)/1"|bc )
        if [ $_amnt -gt 10 ]
        then
          echo "Exiting due to rain past 24hr > 10mm"
          _careMessage="$_careMessage too much rain in the past 24hrs"
          let _skipWatering++
        fi
        _amnt=$( echo "scale=0;( $( $_mqtt_bin_sub -C 1 -h "$_mqtt_broker" -i "$_mqtt_id" -t "sensors/weather/rain_cm" )*10)/1"|bc )
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

function cleaner() {
	echo "Shutting Valve: $valve to $OFF"
	/usr/local/bin/gpio write $valve $OFF
	set -u valve OFF ON
}
function getRelNum {
  local name="$1"
  for (( i=0;i<${#sprinklers[@]};i++ ))
  do
    [ "A$name" == "A${sprinklers[$i]}" ] && break
  done
  [ $i -lt ${#sprinklers[@]} ] && echo "$i" || echo "Failed to find $name"
}

trap "{ cleaner $valve; exit 255; }" SIGINT SIGTERM SIGHUP
 
[ ${#1} -gt 1 ] && valve=$( getRelNum $1 ) || valve=$1
if [ "A$valve" == "A" ] || [ $valve -lt 0 ] || [ $valve -gt 5 ]
then
	echo "Usage: $0 [-c] VALVE [duration in seconds]"
	echo " "
	echo " -c	called from cron - check rain past X days"
	echo " "
	echo "	where VALVE is either the name of the sprinkler"
        echo "   or a numeric value between 0 and 5"
	echo " "
        echo "ToDo: the following are the old values"
	echo " 0 - hedge Bushhose"
	echo " 1 - sprinklers by the shed"
	echo " 2 - garage"
	echo " 3 - Flowers Behring"
	echo " 4 - Torrent"
	echo " duration is optional, default is taken from config file and"
        echo "  differs per valve - given in seconds"
	exit 1
fi
if [ "A$2" != "A" ]
then
  duration=$2
else
  duration=${durations[$valve]}
fi
for (( i=0;i<${#sprinklers[@]};i++ ))
do
	$switcher $i $OFF
done
sleep 1
date -d "+ 1 hour" +%s >$wateringfile
$switcher $valve $ON 
/usr/bin/mosquitto_pub -h pi3gate.localdomain -i "pi/garden" -m 1 -r -t "sprinklers/${sprinklers[$valve]}/state"
sleep 3
$( /usr/local/bin/water-guard.sh & )
sleep $duration
$switcher $valve $OFF
/usr/bin/mosquitto_pub -h pi3gate.localdomain -i "pi/garden" -m 0 -r -t "sprinklers/${sprinklers[$valve]}/state"
