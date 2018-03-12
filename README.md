# My-House

A collection of scripts and tools I use to manage my smart-home.

## Table of Contents

 - [Sensors](#sensors)
 - [Seriveces](#services)
 - [Devices](#devices)
 
 
 ## Sensors
 #### Electricity
 * [E-Meter](sensors/emeter)
 * [Solar](sensors/piko)
 * Batteries
 
 
 #### Environment
 * [Weather](#weather) Station
 
 
 ## Services
 * [MQTT-Listener](services/)
 
 
 ## Devices
 * Amazon Echo
 * Google Home
 * Philips HUE
 * Neeo Smart Remote
 * EnOcean radio switches
 
 
 Since there's a huge amount of different concepts and technologies floating around the market, I chose to glue it all together via MQTT. Diverse **sensors** meter things at various (network-) locations and dump their values to an MQTT-Broker.
 **Services** listen to specific 'topics' from the MQTT broker and then act accordingly.
 
 Simple example: An emeter **sensor** continously reads out the electrical consumption and posts it to the MQTT-Topic sensors/emeter/watt/L1 for the first phase (what electritions usually call 'L1'). If that value goes negative, I'm currently producing more electricity than I'm consuming. If the average over all 3 phases goes below - lets say -500Watts - I have enough electrical power "left over" to e.g. start the water-heating-heat-pump. This would be done by a **service**.
Another example would be Wemos "server" implemented in Python, listening for requests e.g. from Amazon's Echo and posting the request to the MQTT-Topic e.g. "lights/dining light/set_state". A **service** subscribed to that topic would then pick up that request and flip the according relais.
 
 
 For me, Amazon's Echo (aka "Alexa") works the best, with most features implemented. It can talk to a large variety of local hardware, as well as online services. Google's (currently) slightly behind - they can, like Amazon's Echo, control a Philips HUE bulb, but only by accessing Philips' web-service, whilst Amazon's Echo can at least turn it on, off and dimm it locally. Technically this means the request "Alexa|Google turn on dining light" happens in 2 different ways:
 - Google records audio, sends it to its servers, logs into your Hue account & tells it which bulb should be turned on. This is picked up by your Philips bridge, which then switches the bulb on.
 - Amazon records audio, sends it to its servers, receives the reply, tells your Philips bridge locally to turn on the bulb (unfortunately, if you want to set the colour to e.g. blue, Amazon's path is the same as Google's - more on that in the "wemo-emulator")
 - Apple's homebridge I've implemented, but neglected - it's just too clumsy to look for my iPad and then tell it or Siri to turn on the dining light (though it's path is also local) - I might as well press the EnOcean-radio switch
 
 
 #### Weather Station
 
 A cheap & simple weather station WS3080 by Velleman, connected to Raspi with [Weewx](http://weewx.com) and added [MQTT-Module](http://lancet.mit.edu/mwall/projects/weather/releases/weewx-mqtt-0.17.tgz). I installed the debian package from the download page, downloaded the mqtt-extension and ran "wee_extension --install weewx-mqtt-0.17.tgz" to have the **sensor** publishing to the mqtt topic "sensors/weather/\*". I also [patched the driver](sensors/weather/) to include the illuminance value.
 
