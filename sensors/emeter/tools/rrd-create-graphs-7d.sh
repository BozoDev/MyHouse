#!/bin/bash

rrdf="/run/emeter/./emeter.rrd"
picdir="/run/emeter"
outpower="$picdir/power"
outinout="$picdir/im-export"
outwatt="$picdir/watt"
outl="$picdir/l"
outl1="$picdir/l1"
outl2="$picdir/l2"
outl3="$picdir/l3"
outrelais="$picdir/relais"

for _day in 7 30
do
  rrdtool graph "$outpower-${_day}d.png" -a PNG --title="Emeter Power (Amps) - past ${_day} days" --vertical-label "Output Amps" -w 785 -h 200 \
  --font DEFAULT:7: --watermark "`date`" --alt-y-grid --rigid \
  --start "-${_day}days" \
  'DEF:l1in='$rrdf':l1in:AVERAGE' \
  'CDEF:l1an=l1in,1,/' \
  'DEF:l2in='$rrdf':l2in:AVERAGE' \
  'CDEF:l2an=l2in,1,/' \
  'DEF:l3in='$rrdf':l3in:AVERAGE' \
  'CDEF:l3an=l3in,1,/' \
  'DEF:l1id='$rrdf':l1id:AVERAGE' \
  'CDEF:l1ad=l1id,1,/' \
  'DEF:l2id='$rrdf':l2id:AVERAGE' \
  'CDEF:l2ad=l2id,1,/' \
  'DEF:l3id='$rrdf':l3id:AVERAGE' \
  'CDEF:l3ad=l3id,1,/' \
  'LINE1:l1an#0000F0:L1 Amps' \
  'LINE1:l2an#00F000:L2 Amps' \
  'LINE1:l3an#F0F000:L3 Amps' \
  'LINE1:l1ad#000060:L1 Amps demand' \
  'LINE1:l2ad#006000:L2 Amps demand' \
  'LINE1:l3ad#D0B000:L3 Amps demand' \
  'COMMENT:\n' \
  'COMMENT:Line\tAmps Last\tMin\tMax\tDemand Last\tMin\tMax\n' \
  'GPRINT:l1an:LAST:L1\t\t%2.2lf' \
  'GPRINT:l1an:MIN:%2.2lf' \
  'GPRINT:l1an:MAX:%2.2lf' \
  'GPRINT:l1ad:LAST:\t%2.2lf' \
  'GPRINT:l1ad:MIN:%2.2lf' \
  'GPRINT:l1ad:MAX:%2.2lf A\n' \
  'GPRINT:l2an:LAST:L2\t\t%2.2lf' \
  'GPRINT:l2an:MIN:%2.2lf' \
  'GPRINT:l2an:MAX:%2.2lf' \
  'GPRINT:l2ad:LAST:\t%2.2lf' \
  'GPRINT:l2ad:MIN:%2.2lf' \
  'GPRINT:l2ad:MAX:%2.2lf A\n' \
  'GPRINT:l3an:LAST:L3\t\t%2.2lf' \
  'GPRINT:l3an:MIN:%2.2lf' \
  'GPRINT:l3an:MAX:%2.2lf' \
  'GPRINT:l3ad:LAST:\t%2.2lf' \
  'GPRINT:l3ad:MIN:%2.2lf' \
  'GPRINT:l3ad:MAX:%2.2lf A\n'

  rrdtool graph "$outinout-${_day}d.png" -a PNG --title="Emeter Power W / Exported kW/h" --vertical-label "Power W/Export KW/h" -w 785 -h 200 \
  --font DEFAULT:7: --watermark "`date`" --alt-y-grid --rigid \
  --start "-${_day}days" \
  'DEF:l1p='$rrdf':l1p:AVERAGE' \
  'CDEF:l1pi=l1p,1,/' \
  'DEF:l2p='$rrdf':l2p:AVERAGE' \
  'CDEF:l2pi=l2p,1,/' \
  'DEF:l3p='$rrdf':l3p:AVERAGE' \
  'CDEF:l3pi=l3p,1,/' \
  'DEF:l1kwhe='$rrdf':l1kwhe:AVERAGE' \
  'CDEF:l1pe=l1kwhe,1,/' \
  'DEF:l2kwhe='$rrdf':l2kwhe:AVERAGE' \
  'CDEF:l2pe=l2kwhe,1,/' \
  'DEF:l3kwhe='$rrdf':l3kwhe:AVERAGE' \
  'CDEF:l3pe=l3kwhe,1,/' \
  'HRULE:0.0#ff0000:' \
  'LINE1:l1pi#000040:L1 Power i/o W' \
  'LINE1:l2pi#80c000:L2 Power i/o W' \
  'LINE1:l3pi#006000:L3 Power i/o W' \
  'LINE1:l1pe#0000a0:L1 KW/h export' \
  'LINE1:l2pe#8a8a8a:L2 KW/h export' \
  'LINE1:l3pe#cacaca:L3 KW/h export\n' \
  'GPRINT:l1pi:MAX:L1 Max\: %2.2lf W' \
  'GPRINT:l2pi:MAX:L2 Max\: %2.2lf W' \
  'GPRINT:l3pi:MAX:L3 Max\: %2.2lf W\n' \
  'GPRINT:l1pi:MIN:L1 Min\: %2.2lf W' \
  'GPRINT:l2pi:MIN:L2 Min\: %2.2lf W' \
  'GPRINT:l3pi:MIN:L3 Min\: %2.2lf W\n'

  rrdtool graph "$outwatt-${_day}d.png" -a PNG --title="Emeter Power in W - past ${_day} days" --vertical-label "Power W" -w 785 -h 200 \
  --font DEFAULT:7: --watermark "`date`" --alt-y-grid --rigid \
  --start "-${_day}days" \
  'DEF:l1p='$rrdf':l1p:AVERAGE' \
  'CDEF:l1pi=l1p,1,/' \
  'DEF:l2p='$rrdf':l2p:AVERAGE' \
  'CDEF:l2pi=l2p,1,/' \
  'DEF:l3p='$rrdf':l3p:AVERAGE' \
  'CDEF:l3pi=l3p,1,/' \
  'HRULE:0.0#ff0000:' \
  'LINE1:l1pi#00c000:L1 Power i/o W' \
  'LINE1:l2pi#80c000:L2 Power i/o W' \
  'LINE1:l3pi#006000:L3 Power i/o W\n' \
  'COMMENT:\tL1\t\tL2\t\tL3\n' \
  'GPRINT:l1pi:MAX:Max\t%2.2lf W' \
  'GPRINT:l2pi:MAX:%2.2lf W' \
  'GPRINT:l3pi:MAX:%2.2lf W\n' \
  'GPRINT:l1pi:MIN:Min\t%2.2lf W' \
  'GPRINT:l2pi:MIN:%2.2lf W' \
  'GPRINT:l3pi:MIN:%2.2lf W\n'

  for (( o=1;o<4;o++ ))
  do
    rrdtool graph "$outl${o}-${_day}d.png" -a PNG --title="Emeter Power on L${o} in W for the past ${_day} days" --vertical-label "Power W" -w 785 -h 200 \
    --font DEFAULT:7: --watermark "`date`" --alt-y-grid --rigid \
    --start "-${_day}days" \
    'DEF:l1p='$rrdf':l'${o}'p:AVERAGE' \
    'CDEF:l1pi=l1p,1,/' \
    'DEF:l1in='$rrdf':l'${o}'in:AVERAGE' \
    'CDEF:l1an=l1in,230,*' \
    'DEF:l1id='$rrdf':l'${o}'id:AVERAGE' \
    'CDEF:l1ad=l1id,230,*' \
    'HRULE:0.0#ff0000:' \
    'LINE1:l1pi#00c000:L'${o}' Power i/o W' \
    'LINE1:l1an#0000F0:L'${o}' Watts' \
    'LINE1:l1ad#000060:L'${o}' Watts demand\n' \
    COMMENT:"$(printf '%-12s %10s %10s' 'Type' 'Max' 'Min')\n" \
    GPRINT:l1pi:MAX:"$(printf '%-12s %10s' 'Directional' %2.2lfW)" \
    GPRINT:l1pi:MIN:"$(printf '%10s %1s' %2.2lf 'W')\n" \
    GPRINT:l1an:MAX:"$(printf '%-12s %10s' 'Power' %2.2lfW)" \
    GPRINT:l1an:MIN:"$(printf '\r%10s %1s' %2.2lf 'W')\n" \
    GPRINT:l1ad:MAX:"$(printf '%-12s %10s' 'Demand' %2.2lfW)" \
    GPRINT:l1ad:MIN:"$(printf '%10s' %2.2lfW)\n"

  done
done
