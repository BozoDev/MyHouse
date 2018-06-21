#!/bin/bash

DEBUG=0
_ip=""
i=0

while :
do
	_ip="$( ifconfig wlan0 |grep inet|sed 's/.*inet addr:\([0-9.]*\) .*/\1/g' )"
	if [ "A$_ip" != "A192.168.1.23" ]
	then
		echo "Ip on WLan0 gone @ $( date +%H%M )" >>/root/iffer.txt
		echo "Trying to re-start network..." >>/root/iffer.txt
		/etc/init.d/networking stop
		sleep 3
		/etc/init.d/networking start
		ifconfig >>/root/iffer.txt
		sleep 20
		ifconfig >>/root/iffer.txt
		echo -ne "$( date )\n----------------------------------------------------------------------------------\n" >>/root/iffer.txt
	fi
	sleep 100
	let i++
	if [ $i -gt 10 ] && [ $DEBUG -gt 0 ]
	then
		i=0
		ifconfig >>/root/net_stat.txt
		tail -n 200 /var/log/messages >>/root/mess.txt
		echo -ne "$( date )\n----------------------------------------------------------------------------------\n" >>/root/mess.txt
	fi
done

