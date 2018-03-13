# E-Meter

I have an e-meter Eastron & BG E-Tech called **SDM630-Modbus** - quite a nifty device actually. It has a Modbus-over-RS485 interface, meters 3 phases & can also measure the electricity direction - i.e. tell you if you im- or exporting electricity. They offer that device with a pile of different interfaces (modbus, mbus,...) so pay attention to the details.

Here the scripts used to read from an emeter Eastron SDM630-Modbus
It retrieves the values via a small python snippet & publishes them to an MQTT Broker (and optionally updates an rrd-db).

#### Installation

```shell
sudo pip install modbus-tk
sudo cp emeter-reader.py /usr/local/bin/
```
Best choice is probably to install as systemd-service. Check the files provided in the [tools](tools/) folder.

#### Note
I have strange "echos" on my RS485 line. Possibly due to my sloppy cable wiring, but more likely due to my USB-to-RS485 adapter. To cut a long story short, research "FTDI RS485 modbus trailing 1". Which is where I started - conclusion: there seems to be a design issue with USB adapters and Modbus, mainly due to timing requirements. Whilst receiving those trailing chars that mucked up error-detection, I decided to try FTDI's linux drivers (not the kernel included ones). I downloaded compiled & then ran every example once to see which one would suit me best. After that I realized the trailing char had gone, only to be replaced by a leading zero now. Unwilling to plough through all the examples and figure out which one changed what/which FTDI internal registers of my Digitus RS485 to USB adapter (let alone research the original setting), decided to [patch](modbus_tk.patch) the [modbus_tk lib](https://pypi.python.org/pypi/modbus_tk) to try and ignore the obviously stray 1st byte. Works (nearly all-)most of the time.
