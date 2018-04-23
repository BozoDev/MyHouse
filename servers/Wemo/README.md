About the Wemo-Emulator

First things first: big thanks to [Maker Musings](http://www.makermusings.com/2015/07/13/amazon-echo-and-home-automation/) for the original "[Fauxmo](https://github.com/makermusings/fauxmo)" Python code.

Basic concept:
Listen to UPnP-SSDP-Search requests on the network & give similar answers a Wemo&reg; device would.
By 'similar' I mean a reduced functionality - I doubt anybody would like to receive a firmware
update for the emulator ;)


The original idea was to enable Amazon&reg;'s Alexa to control something that had an on/off
(or toggle) URL.
I had a relay-card (own design, since 16 relays) that I wanted to control via Alexa. So I created a
simple cgi-script based web-gui and configured fauxmo to expose each relay to Alexa. This meant that
saying "Alexa, turn on kitchen light" would trigger a http-get `"raspi/cgi-bin/relcard.cgi?relais=1&cmd=on"`
to the raspi with the relay card. Now, the original Fauxmo code had some bug - after exposing a rough 8
devices to Alexa, it would die after some time with 'too many open files' - a simple cron-restart-it-every-3-hrs
kinda fixed that, but my demands grew - more devices wanted to be controlled and in the mean time,
not only by Alexa, which was the bigger pain. Alexa was pretty cool in that respect - it didn't want
to know about device-state changes and such. Just fire its call, wait for a simply 'all fine' reply and
done. Others - like [homebridge](/nfarina/homebridge) (NodeJS module to enable Apple&reg;'s Siri) - were
not so forgiving...

So, here we are now - the "Wemo-Emulator" can now keep track of subscribers (well, sort of - no unsubscribe; only
remove subscriber on send-error,...), notify them of changes, query devices for their state (like someone uses
that Web-GUI on my raspi to 'manually' toggle a relay/light or a cronjob decides to water the garden...).

Since I have more than one Raspi with attached relay-cards, a shell-script MQTT listener runs in the
background sending a USR1 singnal to the "Wemo-Emulator" when it receives state changes of relevant devices.

Some hints if you want to use the code:
-  The original Fauxmo code can be considered 'elderly' in IT terms - I used python virtenv to keep nasty surprises
    through python up-dates/-grades to a minimum
-  The code is plastered with debug statements - best pick a few relevant ones and set their level to '0' rather than
    try to raise the level
-  Aparently Alexa only supports up to 16 Wemo&reg; devices, so don't go overboard ;)
-  Being a non-native-python-speaker - so to speak - some of the additions I made will probably make a true python coder's
    hair stand on end - at least I feel that the frequent iterations through lists to retrieve attributes/whatevers should
    be solved more elegantly ( `"select * from switches where name=$_name"` ...)
