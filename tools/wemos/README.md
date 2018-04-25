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
mkdir bin lib tmp
git clone "https://github.com/BozoDev/MyHouse"
cd MyHouse
cp tools/wemos/var/lib/wemos/lib/switches.sh ../../lib/
cp tools/wemos/var/lib/wemos/bin/mqtt_wemos_state.sh ../../bin
exit
sudo su
cd ~wemos/MyHouse
cp tools/wemos/etc/init.d/wemos /etc/init.d
chown root /etc/init.d/wemos
mkdir -p /usr/local/bin
cd /usr/local/bin
ln -s /var/lib/wemos/MyHouse/servers/Wemo/wemos.py .
```

