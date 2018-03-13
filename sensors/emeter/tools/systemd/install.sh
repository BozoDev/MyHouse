#!/bin/bash

echo "Copy & paste the following commands:"

echo "sudo pip install modbus-tk"
echo "sudo useradd -r -s \"/usr/sbin/nologin\" -d \"/var/lib/mqtt-service\" -m -c \"User to run MQTT\" mqtt-service -U mqtt-service"
echo "sudo mkdir -p /var/lib/mqtt-sensors"
echo "sudo chown mqtt-service /var/lib/mqtt-sensors"
find ./*/ -type f -exec echo "sudo cp {} /{}" \;
echo "sudo cp ../../mqtt_emeter.sh /var/lib/mqtt-sensors/"
echo "sudo cp ../../emeter-reader.py /usr/local/bin/emeter-reader.py"
echo "sudo chown mqtt-service /var/lib/mqtt-sensors/mqtt_emeter.sh"
echo "sudo systemctl daemon-reload"
echo "sudo systemctl enable mqtt_emeter"

echo "-------------------"
echo "Check/edit /etc/default/mqtt_emeter"
echo "then run"
echo "sudo service mqtt_emeter start"

