# have cron run this every 5 mins (between 5am & 11pm? - it's solar data!)
picdir="/run/solar"
rrdf="/run/solar/piko.rrd"
outl="$picdir/solar-l"
outwatt="$picdir/solar-watt"
outpower="$picdir/total-power"
outabsl="$picdir/abs-l"

for i in i p
do
  for (( o=1;o<4;o++ ))
  do
    rrdtool graph "$outl-${i}-${o}.png" -a PNG --title="Solar Power on L${o}" --vertical-label "Power" -w 785 -h 200 \
    --font DEFAULT:7: --watermark "`date`" --alt-y-grid --rigid \
    --x-grid MINUTE:10:HOUR:1:MINUTE:120:0:%R \
    'DEF:l1p='$rrdf':l'${o}${i}:AVERAGE' \
    'CDEF:l1pi=l1'${i}',1,/' \
    'HRULE:0.0#ff0000:' \
    'LINE1:l1pi#00c000:L'${o}' Power in W' \
    'COMMENT:\t\t\tCurrent\tMax\t\tMin\n' \
    GPRINT:l1pi:LAST:"$(printf 'Power %14s' %2.2lfW)" \
    GPRINT:l1pi:MAX:"$(printf '%12s' %2.2lfW)" \
    GPRINT:l1pi:MIN:"$(printf '%12s' %2.2lfW)\n"
  done
done

