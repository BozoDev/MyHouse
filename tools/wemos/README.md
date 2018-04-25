### Brief installation instructions

The following is for a raspi:

```
sudo apt-get update && sudo apt-get install python-virtualenv
sudo useradd -r -m -d '/var/lib/wemos' -s '/bin/false' -c 'User to run fake Wemo devices' wemos
sudo -u wemos bash
cd
virtualenv Python
cd Python
. bin/activate
pip install paho_mqtt
# pip install any missing stuff here
deactivate
mkdir bin lib
git clone "https://github.com/BozoDev/MyHouse"
cd MyHouse
cp tools/wemos/var/lib/wemos/lib/switches.sh ../lib/
cp tools/wemos/var/lib/wemos/bin/mqtt_wemos_state.sh ../bin/
exit
sudo su
cd ~wemos/MyHouse
cp tools/wemos/etc/init.d/wemos /etc/init.d/
chown root /etc/init.d/wemos
cp tools/wemos/etc/logrotate.d/wemos /etc/logrotate.d/
chown root /etc/logrotate.d/wemos
mkdir -p /usr/local/bin
cp servers/Wemo/wemos.py /usr/local/bin/
chown root /usr/local/bin/wemos.py
```

Edit `/usr/local/bin/wemos.py`:
-  towards the top of the file you'll see `_lighturlbase`, which can be used to make the list of FAUXMOS more readable if you have several devices that have the same base-URL - same goes for `_sprinklerurlbase`
-  `_mac_address` - used in setup.xml as reply to SSDP-Search requests - has no ':' or '-' - haven't seen a client that cares if it's the real NIC address or uses it to distinguish different devices...
-  change the list of FAUXMOS at the bottom to the devices you'd like to expose
    *  their name (first field) will be the name Alexa uses in command like 'Alexa, turn on kitchen light'
    *  their control URL, first is on, second off and the third (optional) is to query the device for its current state (the latter doesn't matter to Alexa, but other like homebridge do like to be notified on changes)
    *  their type - optional - currently `controllee` is a simple on/off socket and default is omitted. I'm still trying to figure out additional types and their benefit - was hoping for a `dim`...
-  check the remaining variables at the top for anything you may want to alter, but remember that e.g. tmpdir would also need to be adjusted in `/etc/init.d/wemos`

The `~wemos/lib/switches.sh` is used by the MQTT-listener to only send SIG-USR1 to wemos.py on changes it wants to know about. I want to know about some lights and all sprinklers - adjust according to your needs.

The included `/etc/logrotate.d/wemos` is to keep the log-files from overflowing - adjust to your needs (amount, compression,...)
