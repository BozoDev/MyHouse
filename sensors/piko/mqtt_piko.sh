#!/bin/bash

# Small script to connect to a Kostal Piko, read out data & publish and or store in rrd-db
#   it was designed to run in continuous mode (aka via systemd service) & publish data
#   only when status indicates the Piko is in some sort of system up mode
#
# If run via systemd, the configuration values can be set in /etc/defaults/mqtt_piko, so
#   there shouldn't be the need to run long strings of options when started by systemd
#
# Debug-levels:
# 0           no debugging, continuous run
# 1           slightly verbose, continuous run
# 2 & higher  more verbose & single shot mode

while [ ${#@} -gt 0 ]
do
  case "$1" in
    -h|--host)
      _host="$2"
      shift
      shift
      ;;
    -p|--port)
      _port="$2"
      shift
      shift
      ;;
    -i|--id)
      _id=$2
      shift
      shift
      ;;
    -d|--debug)
      DEBUG=$2
      shift
      shift
      ;;
    -r|--rrd)
      rrd_update=1
      shift
      ;;
    -m|--nomqtt)
      mqtt_publish=0
      shift
      ;;
    *)
      echo "${0##*/} [-h|--host HOSTNAME or IP] [-p|--port PORT] [-d|--debug DEBUGLEVEL] [-i|--id ID] [-r|--rrd] [-m|--nomqtt]"
      echo "ID is decimal integer and same as Modbus ID (check settings page in webgui)"
      ;;
  esac
done

DEBUG=${DEBUG:-0}
_host=${_host:-"solar"}
_port=${_port:-81}
_id=${_id:-3}
mqtt_broker=${mqtt_broker:-"pi3gate.localdomain"}
mqtt_topic=${mqtt_topic:-"sensors/solar"}
mqtt_bin="/usr/bin/mosquitto_pub"
mqtt_publish=${mqtt_publish:-1}
rrd_update=${rrd_update:-0}
[ $rrd_update -gt 0 ] && rrd_db=${rrd_db:-"/run/solar/piko.rrd"}
_vals[0]=0
# Some versions of nc require '-q 2' (rasbian on a Pi3), others will not work with it
_nc="/bin/nc -w 2"
# _nc="/bin/nc -q 2 -w 2"

_id="$( printf '%x' $_id )"
[ ${#_id} -lt 2 ] && _id="0${_id}"

# 57 Get Inverter Status (0=Stop; 1=dry-run; 3..5=running)
# 90 Get Inverter Model
# 8a Get Inverter Version
# 44 Get Inverter Name
# 50 Get Inverter SN
# 51 Get Inverter SN 2?
# 45 Get Total Wh
# 9d Get Today Wh
# 46 Get Total Running time
# 5b Get Total Install time
# 5d Get Last history update time and interval
# 5e
# 92 Get Portal Name & Update Timer
# a6
# 43 Get Technical data

# Sent this:
#  62-03-03-03-00-57-3e-00
#  62-03-03-03-00-43-52-00

# Answer to techn-data-req (43):
# 00000000  e2 03 03 03 00 e6 0a c6  00 2a 02 80 4c 09 40 bf  |.........*..L.@.|
# 00000010  0a c9 00 29 02 40 4d 0a  c0 00 00 00 00 00 00 00  |...).@M.........|
# 00000020  f7 03 00 04 09 a1 00 58  01 c0 51 fc 08 a0 00 55  |.......X..Q....U|
# 00000030  01 c0 51 fc 08 a1 00 56  01 a0 53 4d 1a 3c 00 00  |..Q....V..SM.<..|
# 00000040  00 06 00 00 00 00 00 55  00                       |.......U.|
_calcSum() {
  local c=0 a="$1" i=""

  [ $DEBUG -gt 2 ] && >&2 echo "DEBUG: calcing on \"$a\""
  for i in $( echo $a |sed 's/\\x/ /g' )
  do
    let c-=$( echo $(( 0x$i )) )
    let c%=256
  done
  c="$( printf '%x' $c)"
  echo -n ${c:$(( ${#c} - 2 ))}
}

_readValsFromPiko() {
# Try and read from a Kostal Piko
#  return vals:
#  1 0-length reply (correct IP/Port?)
#  2 Checksum mismatch
#  3 reply-header mismatch
  local _cmd="$1" _hdr="\\x62\\x${_id}\\x03\\x${_id}\\x00" _csum=0 _reply="" i="" _r[0]="" _t=""

  _request="$_hdr\\x$_cmd"
  [ $DEBUG -gt 3 ] && >&2 echo "DEBUG: sending \"$_request\" to csum"
  _csum="$( _calcSum "$_request" )"
  _request="$_request\\x$_csum\\x00"
  [ $DEBUG -gt 2 ] && >&2 echo "DEBUG: will send request: \"$_request\""
  _reply="$( echo -ne "$_request" | $_nc "$_host" "$_port" 2>/dev/null |hexdump  -ve '1/1 "%.2x "' )"
  [ $DEBUG -gt 1 ] && >&2 echo "DEBUG: Received reply: \"$_reply\""
  [[ -z $_reply ]] && >&2 echo "0 reply received" && return 1
  _r=( $_reply )
  [ $DEBUG -gt 2 ] && >&2 echo "DEBUG: received ${#_r[@]} bytes in reply"
  if [ "${_r[0]} ${_r[1]} ${_r[2]} ${_r[3]} ${_r[4]}" != "e2 $_id 03 $_id 00" ]
  then
    >&2 echo "Error in received header (not the expected piko?)"
    return 3
  fi
  # Since pos 0 is first byte:
  for (( i=$(( ${#_r[@]} - 3 ));i>=0;i-- ))
  do
    _t="\\x$( echo ${_r[$i]})$_t"
  done
  [ $DEBUG -gt 2 ] && >&2 echo "DEBUG: Will calc csum on \"$_t\""
  _csum=$( _calcSum "$_t" )
  [ $DEBUG -gt 1 ] && >&2 echo "DEBUG: calced csum from reply: $_csum returned csum: ${_r[$(( ${#_r[@]} - 2 ))]}"
  if [ "A$_csum" == "A${_r[$(( ${#_r[@]} - 2 ))]}" ]
  then
    [ $DEBUG -gt 1 ] && >&2 echo "CSum mach"
    # Remove hdr & csum from reply:
    unset _r[$(( ${#_r[@]} - 1 ))]
    unset _r[$(( ${#_r[@]} - 1 ))]
    for i in {0..4}
    do
      unset _r[$i]
    done
    echo "${_r[@]}"
  else
    >&2 echo "CSum error"
    return 2
  fi
}

_techBytes2Vals() {
  local _bytes=( $( echo "$@" ) ) _vals[0]="" i=0

  [ $DEBUG -gt 0 ] && >&2 echo "DEBUG: converting: #${#_bytes[@]} from \"${_bytes[@]}\""
  for (( i=0;i<${#_bytes[@]};i+=2 ))
  do
    echo -ne "$(( 0x${_bytes[$(( $i+1 ))]}${_bytes[$i]} )) "
  done
}

_getStatus() {
  local _reply=( $@ )
  case ${_reply[0]} in
    00)
      echo "Off"
      return 5
      ;;
    01)
      echo "Idle"
      return 4
      ;;
    02)
      echo "Starting"
      return 3
      ;;
    03)
      echo "Running-MPP"
      return 0
      ;;
    04)
      echo "Running-Regulated"
      return 0
      ;;
    05)
      echo "Running"
      return 0
      ;;
    *)
      echo "Unknow"
      return 2
      ;;
  esac
}

while true
do
  [[ $DEBUG -eq 1 ]] && sleep 26
  i=0
  # for s in 57 43
  # do
  #   r[$i]="$( _readValsFromPiko $s )"
  #   _R=$?
  #   [ $DEBUG -gt 2 ] && >&2 echo "DEBUG: _readValsFromPiko returned $_R"
  #   [ $DEBUG -gt 0 ] && >&2 echo "DEBUG: \"${r[$i]}\" at $i"
  #   let i++
  # done

# Get Status from Piko:
  r=( $( _readValsFromPiko 57 ) )
  _r=$?
  [ $DEBUG -gt 1 ] && echo "DEBUG: ReadVals returned: $_r"
  if [ $_r -ne 0 ]
  then
    [ $DEBUG -gt 1 ] && exit 1
    echo "Error #$_r receiving reply from Piko"
    continue
  fi
  [ $DEBUG -gt 0 ] && echo -ne "Status: " && _getStatus "${r[@]}"

# Does Status justify further data-requests?
  if [[ $(( 0x${r[0]} )) -lt 3 || $(( 0x${r[0]} )) -gt 5 ]]
  then
    [[ $DEBUG -gt 1 ]] && exit 0 || continue
  fi

# Get actual vals
  r=( $( _readValsFromPiko 43 ) )
  _r=$?
  [ $DEBUG -gt 1 ] && echo "DEBUG: ReadVals returned: $_r"
  if [ $_r -ne 0 ]
  then
    [ $DEBUG -gt 1 ] && exit 1
    echo "Error #$_r receiving reply from Piko"
    continue
  fi

  _vals=( $( _techBytes2Vals ${r[@]} ) )
  [ $DEBUG -gt 2 ] && echo "DEBUG: String of tech-vals: ${_vals[@]}"

# Put values in array of DC{1|2|3}="Volts*10 Amps*100 Watt Temp1 Temp2"
  for o in {0..2}
  do
    eval "DC$(( $o + 1 ))"='( $( for i in {0..4};do echo -n "${_vals[$(( $o * 5 + $i ))]} ";done ) )'
  done
  [ $DEBUG -gt 1 ] && echo "DEBUG: DC1-Watt=${DC1[2]} DC2-Watt=${DC2[2]} DC3-Watt=${DC3[2]}"

# Put values in array of AC[1|2|3]="Volts*10 Amps*100 Watt Temp1"
  for o in {0..2}
  do
    eval "AC$(( $o + 1 ))"='( $( for i in {0..3};do echo -n "${_vals[$(( 15 + $o * 4 + $i ))]} ";done ) )'
  done
  [ $DEBUG -gt 0 ] && echo "DEBUG: AC1-Watt=${AC1[2]} AC2-Watt=${AC2[2]} AC3-Watt=${AC3[2]}"
  [ $DEBUG -gt 1 ] && echo "DEBUG: AC1-Volt=$( echo "scale=2;${AC1[0]}/10"|bc ) AC2-Volt=$( echo "scale=2;${AC2[0]}/10"|bc ) AC3-Volt=$( echo "scale=2;${AC3[0]}/10"|bc )"

# Publish the stuff...
  if [ $mqtt_publish -gt 0 ]
  then
    # for i in {1..3}
    # do
    #   _varn="AC${i}[1]"
    #    $mqtt_bin -h "$mqtt_broker" -i piko-updater -t "${mqtt_topic}/amps/L$i" -m "${!_varn}"
    # done
    for i in {1..3}
    do
      _varn="AC${i}[2]"
      $mqtt_bin -h "$mqtt_broker" -i piko-updater -t "${mqtt_topic}/watt/L$i" -m "${!_varn}"
    done
  fi
  [[ $rrd_update -gt 0 ]] && rrdtool update $rrd_db "N:${AC1[1]}:${AC2[1]}:${AC3[1]}:${AC1[2]}:${AC2[2]}:${AC3[2]}"
  [[ $DEBUG -gt 1 ]] && exit 0
done

