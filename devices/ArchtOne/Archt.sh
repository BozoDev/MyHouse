#!/bin/bash
DEBUG=0

_init_cmd="00 03 13 05 0e"
_init_cmds=( "00 03 15 05 10" "00 03 1b 05 16" "00 03 0b 05 06" "00 03 1d 05 18" "00 03 04 00 04" "00 03 09 05 04" "00 03 1f 05 1a" )
# Very loud:  "00 04 27 05 05 1d"
# Normal:     "00 04 20 05 05 16"
_archt_commands=( "00 03 09 05" "00 04 20 05 05" "00 04 0A 05 05" "00 04 20 05 05" )
_archt_commands_name=( "getVolume" "setVolume" "mute" "normal" )
_loudness_h=( "loud" "normal" )
_loudness_cmds=( "00 04 27 05 05 1d" "00 04 20 05 05 16" )
_devices=( "labomba-l" "labomba-r" )
_port="53011"

if [ "A$1" == "A-s" ]
then
  _devices=( "$2" )
  shift 2
fi
_action="$1"
if [ "A$2" != "A" ] && [ $2 -gt 0 ]
then
  _value=$(( $2 / 2 ))
  [ $_value -lt 10 ] && _value=10
fi

calcCSum() {
  local _calcr=$(( 0x${1} )) _vals=( ${@:2} )

  for i in ${_vals[@]}
  do
    let _calcr-=$(( 0x${i} ))
  done
  _calcr=$( printf '%x' "$_calcr" )
  [ ${#_calcr} -gt 2 ] && _calcr="${_calcr:(-2)}"
  echo "$_calcr"
}

checkReplyCSum() {
  local _csum=$( getCSumFromString ${@} ) _vals="$( getValsFromReply ${@} )"

  [ $DEBUG -gt 1 ] && echo "Given CSum= ${_csum} - calced CSum: $( calcCSum $_vals ) Vals=${_vals}"
  [ $(( 0x$( calcCSum $_vals ) )) -eq $(( 0x$_csum )) ] && return 0 || return 1
}

getCSumFromString() {
  local _csum=${!#}
  echo $_csum
}

getValsFromReply() {
  local i=3
  while [ $i -lt ${#@} ]
  do
    echo -ne " ${!i}"
    let i++
  done
}

getValsFromString() {
  local i=3
  while [ $i -le ${#@} ]
  do
    echo -ne " ${!i}"
    let i++
  done
}

getCmdFromString() {
  echo $1 $2
}

getVolFromReply() {
  echo $3
}

sendCmd2Archt() {
  local _host="$1" _port="$2"
  shift 2
  local r=( $@ )

  printf '%b' "\x$( echo ${r[*]} |sed 's/ /\\x/g' )" |nc -w 2 "$_host" "$_port" 2>/dev/null |hexdump  -ve '1/1 "%.2x "'
}

printVolumeFromReply() {
  local _reply="$@"

  checkReplyCSum $_reply || return 1
  [ ${#_devices[@]} -gt 1 ] && echo -ne "Host ${_host}: "
  echo "$(( 0x$( getVolFromReply $_reply ) * 2 ))"
  return 0
}

getSendBytes() {
  local i=0 _action="$1"

  for (( i=0;i<${#_archt_commands_name[@]};i++ ))
  do
    if [ "A${_archt_commands_name[$i]}" == "A$_action" ]
    then
      echo "${_archt_commands[$i]}"
      return 0
    fi
  done
  return 1
}

getVolume() {
  local _action="getVolume" _sendString="" _vals="" _csum=0 _reply="" i=0

  _sendString=$( getSendBytes $_action ) || exit 1
  _vals="$( getValsFromString $_sendString )"
  _csum="$( calcCSum $_vals )"
  [ $DEBUG -gt 0 ] && echo "DEBUG: sending $_host $_port $_sendString $_csum"
  _reply="$( sendCmd2Archt $_host $_port $_sendString $_csum )"
  [ $DEBUG -gt 0 ] && echo "DEBUG: received reply: \"$_reply\""
  [ "A$_reply" == "A" ] && return 1
  echo $( printVolumeFromReply $_reply )
  return 0
}

_sendString=$( getSendBytes $_action ) || exit 1
[ "A$_sendString" == "A" ] && exit 1
_vals="$( getValsFromString $_sendString )"
_cmd="$( getCmdFromString $_sendString )"
for _host in ${_devices[@]}
do
  case $_action in
    getVolume)
      echo $( getVolume )
      ;;
    mute|normal)
      _csum="$( calcCSum $_vals )"
      [ $DEBUG -gt 1 ] && echo "DEBUG: would send $_sendString $_csum"
      _reply="$( sendCmd2Archt $_host $_port $_sendString $_csum )"
      [ $DEBUG -gt 0 ] && echo "DEBUG: received \"$_reply\""
      [ "A$_reply" == "A" ] && continue 
      sleep 0.5
      echo $( getVolume )
      ;;
    setVolume)
      _v=( $_vals )
      _v[0]=$( printf '%x' "$_value" )
      _csum="$( calcCSum ${_v[*]} )"
      [ $DEBUG -gt 1 ] && echo "DEBUG: would send $_cmd ${_v[*]} $_csum to host: $_host"
      _reply="$( sendCmd2Archt $_host $_port $_cmd ${_v[*]} $_csum )"
      [ $DEBUG -gt 0 ] && echo "DEBUG: received reply: \"$_reply\""
      [ "A$_reply" == "A" ] && continue
      checkReplyCSum $_reply || continue
      sleep 0.5
      echo $( getVolume )
      ;;
    *)
      echo "Command $_action not implemented"
      ;;
  esac
done

