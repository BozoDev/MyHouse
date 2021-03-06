# My-House

A collection of scripts and tools I use to manage my smart-home.

## Table of Contents

 - [Servers](#servers)
 - [Sensors](#sensors)
 - [Services](#services)
 - [Devices](#devices)
 
 ## Servers
  * [Wemo Emulator](#wemo)
  
  
 ## Sensors
 #### Electricity
 * [E-Meter](sensors/emeter)
 * [Solar](sensors/piko)
 * Batteries
 
 
 #### Environment
 * [Weather Station](#weather)
 
 
 ## Services
 * [MQTT-Listener](services/)
 
 
 ## Devices
 * Amazon Echo&reg;
 * Google Home&reg;
 * Philips HUE&reg;
 * Neeo Smart Remote&reg;
 * EnOcean&reg; radio switches
 * Archt One&reg; Network speakers
 
 
 Since there's a huge amount of different concepts and technologies floating around the market, I chose to glue it all together via MQTT. Diverse **sensors** meter things at various (network-) locations and dump their values to an MQTT-Broker.
 **Services** listen to specific 'topics' from the MQTT broker and then act accordingly.
 
 Simple example: An emeter **sensor** continuously reads out the electrical consumption and posts it to the MQTT-Topic `sensors/emeter/watt/L1` for the first phase (what electritions usually call 'L1'). If that value goes negative, I'm currently producing more electricity than I'm consuming. If the average over all 3 phases goes below - lets say -500Watts - I have enough electrical power "left over" to e.g. start the water-heating-heat-pump. This would be done by a **service**.
Another example would be Wemos "server" implemented in Python, listening for requests e.g. from Amazon's Echo and posting the request to the MQTT-Topic e.g. `lights/dining light/set_state`. A **service** subscribed to that topic would then pick up that request and flip the according relais.
 
 
 For me, Amazon's Echo (aka "Alexa") works the best, with most features implemented. It can talk to a large variety of local hardware, as well as online services. Google's (currently) slightly behind - they can, like Amazon's Echo, control a Philips HUE bulb, but only by accessing Philips' web-service, whilst Amazon's Echo can at least turn it on, off and dimm it locally. Technically this means the request "Alexa|Google turn on dining light" happens in 2 different ways:
 - Google records audio, sends it to its servers, logs into your Hue account & tells it which bulb should be turned on. This is picked up by your Philips bridge, which then switches the bulb on.
 - Amazon records audio, sends it to its servers, receives the reply, tells your Philips bridge locally to turn on the bulb (unfortunately, if you want to set the colour to e.g. blue, Amazon's path is the same as Google's - more on that in the "wemo-emulator")
 - Apple's homebridge I've implemented, but neglected - it's just too clumsy to look for my iPad and then tell it or Siri to turn on the dining light (though it's path is also local) - I might as well press the EnOcean-radio switch
 
 
 #### Weather
 
 A cheap & simple weather station WS3080 by Velleman, connected to Raspi with [Weewx](http://weewx.com) and added [MQTT-Module](http://lancet.mit.edu/mwall/projects/weather/releases/weewx-mqtt-0.17.tgz). I installed the debian package from the download page, downloaded the mqtt-extension and ran "wee_extension --install weewx-mqtt-0.17.tgz" to have the **sensor** publishing to the mqtt topic "sensors/weather/\*". I also [patched the driver](sensors/weather/) to include the illuminance value.


 #### Wemo

 Quite a while back I stumbled across some python code called '[fauxmo](https://github.com/makermusings/fauxmo)' - simply put, it can expose anything controlable via on/off URL as Wemo device (to e.g. Alexa). Since I also wanted that e.g. homebridge (NodeJS) could pick up the devices, I had to add quite some code. Homebridge also likes to be informed about device changes, so UPnP subscription handling (basic) had to be added. So, the "[Wemo-Emulator](servers/Wemo)" was born.


#### Archt One

 Cool speakers, connected via WLan - can play from Line-In,USB (Stick),Apple (-cable), BT or WiFi. BUT - AFAIK - the company folded up & the official way to control them is via an App. Since I also wanted to control them via Alexa&reg; "dimm main speakers", I needed a way to change their volume outside the App. [Here](devices/ArchtOne)'s the story...
