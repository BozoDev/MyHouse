#!/bin/bash

### BEGIN INIT INFO
# Provides:		gpIO_init
# Required-Start:	$network $local_fs
# Required-Stop:	$network $local_fs
# Should-Start:
# Should-Stop:
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	Set correct mode for GPIO ports, and switch them off
### END INIT INFO

PATH="/sbin:/bin:/usr/sbin:/usr/bin"
NAME="gpIO_init"
DESC="Set correct mode for GPIO ports, and switch them off"

gpIO="/usr/local/bin/gpio"
ON=0
OFF=1
MAXP=4

test -x $gpIO || exit 2

if [ -r "/etc/default/${NAME}" ]
then
	. "/etc/default/${NAME}"
fi

set -e

case "${1}" in
	start)
		for (( i=0; i <= $MAXP;i++ ))
		do
			$gpIO mode $i output
			$gpIO write $i $OFF
		done
		nohup /usr/local/bin/water_off.sh >/dev/null 2>&1 &
		nohup /usr/local/bin/network_watcher.sh >/dev/null 2>&1 &
		;;

	stop|restart|force-reload)
		for (( i=0; i <= $MAXP; i++ ))
		do
			$gpIO write $i $OFF
		done
		;;

	*)
		echo "Usage: ${0} {start|stop|restart|force-reload}" >&2
		echo "Where start set mode and off, and stop only off" >&2
		exit 1
		;;
esac

exit 0

