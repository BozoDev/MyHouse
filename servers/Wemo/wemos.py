#!/usr/bin/env python

"""
The MIT License (MIT)

Copyright (c) 2015 Maker Musings

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
"""

# For a complete discussion, see http://www.makermusings.com

import email.utils
import requests
import select
import socket
import struct
import sys
import time
import urllib
import uuid
import signal
import pickle
# import paho.mqtt.publish as publish

_DEBUG = 1

FAUSMOS = []
# _devices = []
_lighturlbase='http://pi3gate/cgi-bin/relswitch.cgi?'
_sprinklerurlbase='http://gardenpi/cgi-bin/garden.cgi?'
# _mqtt_broker='pi2gate.localdomain'
_tmpDir='/run/wemos/'
_inUpdate=0

def _dbg(lvl, msg):
  if lvl < _DEBUG:
    date_str = time.strftime("%Y-%m-%d %H:%M-%S")
    print "DEBUG %s: %s" % (date_str, msg)
    sys.stdout.flush()

def save_obj(obj, name ):
    with open( _tmpDir + name + '.pkl', 'w+') as f:
        pickle.dump(obj, f, 0)

def load_obj(name ):
    with open( _tmpDir + name + '.pkl', 'r') as f:
        return pickle.load(f)

def update_switches_state():
  global switches
  _dbg(0,"In update_switches_state")
  i=0
  for switch in switches:
    if switch.action_handler.can_query():
      _dbg(0,"In update_switches_state device %s had state %s" % (switch.name, switch.state))
      switches[i].state = switch.action_handler.query()
      _dbg(0,"In update_switches_state device %s now has state %s" % ( switches[i].name, switches[i].state))
    i += 1
  return

def get_switch_state(_name):
  _dbg(1,"In get_switch_state for %s" % _name)
  for one_faux in FAUXMOS:
    _dbg(3,"checking %s" % one_faux[0])
    try:
      _name_f, _type_f = one_faux[0].split()
    except Exception, e:
      _dbg(1,"Attempt in get_switch_state to split fauxmo name in name and type failed with %s" % e)
      _name_f = one_faux[0]
      _type_f = "switch"
    if _name == _name_f or _name == one_faux[0]:
      if one_faux[1].can_query():
        _dbg(2,"In get_switch_state can query %s" % _name)
        _state = one_faux[1].query()
        _dbg(1,"Returning %s from get_switch_statequery-url" % _state)
        return _state
    else:
      continue
  _dbg(0,"Unknow switch %s requsted for get_switch_state" % _name)
  return -1

def notify_handler(signum, frame):
  global switches
  _dbg(0,"Signal received - checking for changes and notifying subscribers")
  if _inUpdate == 1:
    _dbg(0,"Seem like the In-Update flag is set - skipping")
    return
  _chgd=[]
  i=0
  for switch in switches:
    if switch.action_handler.can_query():
      _dbg(1,"In notify_handler switch %s can query" % switch.name)
      _state_o = str(switch.state)
      _state = str(switch.action_handler.query())
      if _state != _state_o:
        _dbg(0,"In notify_handler new switch state detected for %s old: %s new: %s" % (switch.name, _state_o, _state))
        # Ugly: ToDo: create set_state method in fauxmos class
        switches[i].state = _state
        _chgd.append(i)
      else:
        _dbg(1,"In notify_handler no change detected for %s" % switch.name)
    else:
       _dbg(1,"In notify_handler can't query switch %s" % switch.get_name())
    i += 1
  _dbg(0,"Notifying these: %s" % _chgd)
  for _chg in _chgd:
    _dbg(0,"Will send notify to: %s" % switches[_chg].name )
    switches[_chg].notify_subscribers()

def remove_subscribers(_self, subs):
  _dbg(0,"Entering remove_subscribers")
  _dbg(0,"Trying to remove %s from list of subscribers" % subs)
  _subs=load_obj(_self.subsfile)
  subs_w = []
  for sub_e in subs:
    for _sub in _subs:
      if sub_e == _sub:
        _dbg(0,"Found %s in list of subscribers - won't add" % sub_e)
        continue
      else:
        _dbg(0,"Keeping %s in list of subscribers" % _sub)
        subs_w.append(_sub)
  save_obj(subs_w,_self.subsfile)
  _dbg(0,"Hopefully written: %s" % subs_w)

def send_event(_self):
    _dbg(0,"Entering re-written send_event")
    _host = "%s:%s" % ( _self.ip_address, _self.port )
    _filen = _self.subsfile
    seq = _self.seq
    _self.seq += 1
    subscriptions = []
    subscriptions_e = []
    subscriptions = load_obj(_filen)
    _dbg(0,"Received Subs: %s" % subscriptions)
    subscr = {}
    for subscr in subscriptions:
      _dbg(1,"Received Sub: %s" % subscr)
      ip = subscr['ip']
      port = subscr['port']
      subsurl = subscr['url']
      _dbg(0,"Subscriber: %s:%s on URL: %s" % (ip,port,subsurl))
      destination = (ip, int(port))
      # _state = get_switch_state(_self.name) # <- this was old, but it actually queried the controlled device for its state, rather than just read-out the supposed state
      _state = _self.state
      _dbg(0,"In send_event try getting cached switch state as %s" % _self.state)
      xml = ("<?xml version=\"1.0\"?>"
             "<e:propertyset xmlns:e=\"urn:schemas-upnp-org:event-1-0\">"
             "<e:property>"
             "<BinaryState>%s</BinaryState>"
             "</e:property>"
             "</e:propertyset>"
             "</xml>" % _state)
      message = ("NOTIFY /%s HTTP/1.0\r\n"
                 "HOST: %s\r\n"
                 "CONTENT-TYPE: text/xml; charset=\"utf-8\"\r\n"
                 "CONTENT-LENGTH: %d\r\n"
                 "NT: upnp:event\r\n"
                 "NTS: upnp:propchange\r\n"
                 "SID: uuid:Socket-1_0-%s_sub0000000060\r\n"
                 "SEQ: %d\r\n"
                 "\r\n"
                 "%s" % ( subsurl, _host, len(xml), _self.serial, seq, xml))
      _dbg(0,"Sending Notify #%s to %s:%s /%s for %s" % (seq, ip, port, subsurl, _self.name))
      _dbg(1,"%s" % message)
      _tmpsock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
      try:
        _tmpsock.connect(destination)
        _tmpsock.send(message)
      except Exception, e:
        if int(e[0]) == 111:
          _dbg(0,"Skipping Error %s - removing subscriber" % e[1])
          subscriptions_e.append(subscr)
          continue
        else:
          _dbg(0,"Failed to send Notify with: %s" % e)
          _dbg(0,"removing subscriber...")
          subscriptions_e.append(subscr)
      _tmpsock.shutdown(socket.SHUT_RDWR)
      _tmpsock.close()
      del(_tmpsock)
    if subscriptions_e:
      _dbg(0,"Removing subscribers %s" % subscriptions_e)
      remove_subscribers(_self, subscriptions_e)
    else:
      _dbg(0,"No subscribers to remove")
    return True

# <deviceType>urn:MakerMusings:device:controllee:1</deviceType>

# This XML is the minimum needed to define one of our virtual switches
# to the Amazon Echo

SETUP_XML = """<?xml version="1.0"?>
<root xmlns="urn:Belkin:device-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <device>
    <deviceType>urn:Belkin:device:%(device_type)s:1</deviceType>
    <friendlyName>%(device_name)s</friendlyName>
    <manufacturer>Belkin International Inc.</manufacturer>
    <manufacturerURL>http://www.belkin.com</manufacturerURL>
    <modelName>Emulated Socket</modelName>
    <modelNumber>3.1415</modelNumber>
    <modelURL>http://www.belkin.com/plugin/</modelURL>
    <serialNumber>%(device_serial)s</serialNumber>
    <binaryState>0</binaryState>
    <UDN>uuid:Socket-1_0-%(device_serial)s</UDN>
    <UPC>123456789</UPC>
    <macAddress>b827ebd2f303</macAddress>
    <firmwareVersion>WeMo_WW_2.00.8095.PVT-OWRT-SNS</firmwareVersion>
    <iconVersion>1|49153</iconVersion>
    <iconList>
      <icon>
        <mimetype>jpg</mimetype>
        <width>100</width>
        <height>100</height>
        <depth>100</depth>
        <url>icon.jpg</url>
      </icon>
    </iconList>
    <serviceList>
        <service>
            <serviceType>urn:Belkin:service:basicevent:1</serviceType>
            <serviceId>urn:Belkin:serviceId:basicevent1</serviceId>
            <controlURL>/upnp/control/basicevent1</controlURL>
            <eventSubURL>/upnp/event/basicevent1</eventSubURL>
            <SCPDURL>/eventservice.xml</SCPDURL>
        </service>
        <service>
          <serviceType>urn:Belkin:service:rules:1</serviceType>
          <serviceId>urn:Belkin:serviceId:rules1</serviceId>
          <controlURL>/upnp/control/rules1</controlURL>
          <eventSubURL>/upnp/event/rules1</eventSubURL>
          <SCPDURL>/rulesservice.xml</SCPDURL>
        </service>
        <service>
          <serviceType>urn:Belkin:service:deviceevent:1</serviceType>
          <serviceId>urn:Belkin:serviceId:deviceevent1</serviceId>
          <controlURL>/upnp/control/deviceevent1</controlURL>
          <eventSubURL>/upnp/event/deviceevent1</eventSubURL>
          <SCPDURL>/deviceservice.xml</SCPDURL>
        </service>
    </serviceList>
  </device>
</root>
"""

EVENTSERVICE_XML = """<?xml version="1.0"?>
<scpd xmlns="urn:Belkin:service-1-0">
    <specVersion>
        <major>1</major>
        <minor>0</minor>
    </specVersion>
    <actionList>
        <action>
          <name>SetBinaryState</name>
          <argumentList>
             <argument>
               <retval />
               <name>BinaryState</name>
               <relatedStateVariable>BinaryState</relatedStateVariable>
               <direction>in</direction>
              </argument>
             <argument>
               <retval />
               <name>Duration</name>
               <relatedStateVariable>Duration</relatedStateVariable>
               <direction>in</direction>
              </argument>
             <argument>
               <retval />
               <name>EndAction</name>
               <relatedStateVariable>EndAction</relatedStateVariable>
               <direction>in</direction>
              </argument>
             <argument>
               <retval />
               <name>UDN</name>
               <relatedStateVariable>UDN</relatedStateVariable>
               <direction>in</direction>
              </argument>
          </argumentList>
        </action>
        <action>
          <name>GetFriendlyName</name>
          <argumentList>
            <argument>
              <retval />
              <name>FriendlyName</name>
              <relatedStateVariable>FriendlyName</relatedStateVariable>
              <direction>in</direction>
             </argument>
           </argumentList>
        </action>
        <action>
          <name>GetHomeId</name>
        </action>
        <action>
          <name>GetHomeInfo</name>
          <argumentList>
            <retval />
            <name>GetHomeInfo</name>
            <relatedStateVariable>HomeInfo</relatedStateVariable>
            <direction>out</direction>
          </argumentList>
        </action>
        <action>
          <name>GetDeviceId</name>
        </action>
        <action>
          <name>GetMacAddr</name>
        </action>
        <action>
          <name>GetSerialNo</name>
        </action>
        <action>
          <name>GetPluginUDN</name>
        </action>
        <action>
          <name>GetSmartDevInfo</name>
        </action>
        <action>
          <name>ShareHWInfo</name>
          <argumentList>
             <argument>
               <retval />
               <name>Mac</name>
               <relatedStateVariable>Mac</relatedStateVariable>
               <direction>in</direction>
              </argument>
             <argument>
               <retval />
               <name>Serial</name>
               <relatedStateVariable>Serial</relatedStateVariable>
               <direction>in</direction>
              </argument>
             <argument>
               <retval />
               <name>Udn</name>
               <relatedStateVariable>Udn</relatedStateVariable>
               <direction>in</direction>
              </argument>
             <argument>
               <retval />
               <name>RestoreState</name>
               <relatedStateVariable>RestoreState</relatedStateVariable>
               <direction>in</direction>
              </argument>
             <argument>
               <retval />
               <name>HomeId</name>
               <relatedStateVariable>HomeId</relatedStateVariable>
               <direction>in</direction>
              </argument>
             <argument>
               <retval />
               <name>PluginKey</name>
               <relatedStateVariable>PluginKey</relatedStateVariable>
               <direction>in</direction>
              </argument>
          </argumentList>
        </action>
        <action>
            <name>GetBinaryState</name>
            <argumentList>
                <argument>
                    <retval/>
                    <name>BinaryState</name>
                    <relatedStateVariable>BinaryState</relatedStateVariable>
                    <direction>out</direction>
                </argument>
            </argumentList>
        </action>
    </actionList>
    <serviceStateTable>
      <stateVariable sendEvents="yes">
        <name>BinaryState</name>
        <dataType>string</dataType>
        <defaultValue>0</defaultValue>
      </stateVariable>
      <stateVariable sendEvents="yes">
        <name>FriendlyName</name>
        <dataType>string</dataType>
        <defaultValue>0</defaultValue>
      </stateVariable>
      <stateVariable sendEvents="yes">
        <name>HomeId</name>
        <dataType>string</dataType>
        <defaultValue>0</defaultValue>
      </stateVariable>
      <stateVariable sendEvents="yes">
        <name>DeviceId</name>
        <dataType>string</dataType>
        <defaultValue>0</defaultValue>
      </stateVariable>
      <stateVariable sendEvents="yes">
        <name>SmartDevInfo</name>
        <dataType>string</dataType>
        <defaultValue>0</defaultValue>
      </stateVariable>
      <stateVariable sendEvents="yes">
        <name>MacAddr</name>
        <dataType>string</dataType>
        <defaultValue>0</defaultValue>
      </stateVariable>
      <stateVariable sendEvents="yes">
        <name>SerialNo</name>
        <dataType>string</dataType>
        <defaultValue>0</defaultValue>
      </stateVariable>
      <stateVariable sendEvents="yes">
        <name>PluginUDN</name>
        <dataType>string</dataType>
        <defaultValue>0</defaultValue>
      </stateVariable>
      <stateVariable sendEvents="no">
        <name>UDN</name>
        <dataType>string</dataType>
        <defaultValue>0</defaultValue>
      </stateVariable>
    </serviceStateTable>
</scpd>
"""

# A simple utility class to wait for incoming data to be
# ready on a socket.

class poller:
    def __init__(self):
        if 'poll' in dir(select):
            self.use_poll = True
            self.poller = select.poll()
        else:
            self.use_poll = False
        self.targets = {}

    def add(self, target, fileno = None):
        if not fileno:
            fileno = target.fileno()
        if self.use_poll:
            self.poller.register(fileno, select.POLLIN)
        self.targets[fileno] = target

    def remove(self, target, fileno = None):
        if not fileno:
            fileno = target.fileno()
        if self.use_poll:
            self.poller.unregister(fileno)
        del(self.targets[fileno])

    def poll(self, timeout = 0):
        if self.use_poll:
            ready = self.poller.poll(timeout)
        else:
            ready = []
            if len(self.targets) > 0:
                (rlist, wlist, xlist) = select.select(self.targets.keys(), [], [], timeout)
                ready = [(x, None) for x in rlist]
        for one_ready in ready:
            target = self.targets.get(one_ready[0], None)
            if target:
                target.do_read(one_ready[0])
 

# Base class for a generic UPnP device. This is far from complete
# but it supports either specified or automatic IP address and port
# selection.

class upnp_device(object):
    this_host_ip = None

    @staticmethod
    def local_ip_address():
        if not upnp_device.this_host_ip:
            temp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            try:
                # temp_socket.connect(('8.8.8.8', 53))
                temp_socket.connect(('192.168.1.2', 53))
                upnp_device.this_host_ip = temp_socket.getsockname()[0]
            except:
                upnp_device.this_host_ip = '127.0.0.1'
            del(temp_socket)
            _dbg(1, "got local address of %s" % upnp_device.this_host_ip)
        return upnp_device.this_host_ip

    def __init__(self, listener, poller, port, root_url, server_version, persistent_uuid, other_headers = None, ip_address = None):
        self.listener = listener
        self.poller = poller
        self.port = port
        self.root_url = root_url
        self.server_version = server_version
        self.persistent_uuid = persistent_uuid
        self.uuid = uuid.uuid4()
        self.other_headers = other_headers

        if ip_address:
          self.ip_address = ip_address
        else:
          self.ip_address = upnp_device.local_ip_address()

        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.socket.bind((self.ip_address, self.port))
        self.socket.listen(5)
        if self.port == 0:
          self.port = self.socket.getsockname()[1]
        self.poller.add(self)
        self.client_sockets = {}
        self.listener.add_device(self)

    def fileno(self):
        return self.socket.fileno()

    def do_read(self, fileno):
        if fileno == self.socket.fileno():
            (client_socket, client_address) = self.socket.accept()
            self.poller.add(self, client_socket.fileno())
            self.client_sockets[client_socket.fileno()] = client_socket
        else:
            data, sender = self.client_sockets[fileno].recvfrom(4096)
            if not data:
                self.poller.remove(self, fileno)
                del(self.client_sockets[fileno])
            else:
                self.handle_request(data, sender, self.client_sockets[fileno])
                self.poller.remove(self, fileno)
                del(self.client_sockets[fileno])

    # def handle_request(self, data, sender, socket):
    #     pass

    def get_name(self):
        return "unknown"
        
    def respond_to_search(self, destination, search_target):
        _dbg(1, "Responding to search for %s dest: %s" % (self.get_name(), destination))
        date_str = email.utils.formatdate(timeval=None, localtime=False, usegmt=True)
        location_url = self.root_url % {'ip_address' : self.ip_address, 'port' : self.port}
        message = ("HTTP/1.1 200 OK\r\n"
                  "CACHE-CONTROL: max-age=86400\r\n"
                  "DATE: %s\r\n"
                  "EXT:\r\n"
                  "LOCATION: %s\r\n"
                  "OPT: \"http://schemas.upnp.org/upnp/1/0/\"; ns=01\r\n"
                  "01-NLS: %s\r\n"
                  "SERVER: %s\r\n"
                  "ST: %s\r\n"
                  "USN: uuid:%s::%s\r\n" % (date_str, location_url, self.uuid, self.server_version, search_target, self.persistent_uuid, search_target))
        if self.other_headers:
            for header in self.other_headers:
                message += "%s\r\n" % header
        message += "\r\n"

        _tmpsock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
          _tmpsock.connect(destination)
          _tmpsock.send(message)
        except Exception, e:
          _dbg(0,"Failed to send search-response with: ")
          _dbg(0,e)
        # _tmpsock.shutdown(socket.SHUT_RDWR)
        _tmpsock.close()
        del(_tmpsock)

# This subclass does the bulk of the work to mimic a WeMo switch on the network.

class fauxmo(upnp_device):
    @staticmethod
    def make_uuid(name):
        return ''.join(["%x" % sum([ord(c) for c in name])] + ["%x" % ord(c) for c in "%sfauxmo!" % name])[:14]

    def update_subscription( _self, subs, subsurl):
        _dbg(0,"Entering update_subscription")
        _filename = _self.subsfile
        _nusubs = []
        _host, _port = subs.split(":")
        _nusubs[:] = []
        f = 0
        _subsr = []
        try:
          _subsr = load_obj(_filename)
          _dbg(1,"Read subscriber file")
        except:
          _dbg(0,"Couldn't read subscriptions from file (empty?)")
        line = {}
        for line in _subsr:
          if line['ip'] == _host:
            _dbg(1,"Found host \"%s\" in \"%s\"" % (_host, line))
            if line['port'] == _port:
              _dbg(1,"Found host \"%s\" on same port %s" % (_host, _port))
              if line['url'] == subsurl:
                _dbg(0,"No changes in ip, port or url for \"%s\"" % _host)
                return True
              else:
                _dbg(0,"New URL for existing host \"%s\"" % _host)
                f = 1
                _nusubs.append([{'ip': _host, 'port': _port, 'url': subsurl}])
                continue
            else:
              _dbg(0,"Found same host on new port: %s old: %sx)" % (_port, line['port']))
              f = 1
              _nusubs.append({'ip': _host, 'port': _port, 'url': subsurl})
              continue
          else:
            _dbg(0,"Host \"%s\" not in \"%s\"" % (_host, line) )
            _nusubs.append(line)
        if f != 1:
          # I think this happens on empty file... no for, no if..else hence file stays empty
          _nusubs.append({'ip': _host, 'port': _port, 'url': subsurl})
        save_obj(_nusubs, _filename)
        return

    def notify_subscribers(_self):
      send_event(_self)

    def renew_subscr(_self):
      _dbg(0,"Entering nu renew_subscr")
      _host = "%s:%s" % ( _self.ip_address, _self.port )
      subscriptions = load_obj(_self.subsfile)
      for subscript in subscriptions:
        ip = subscript['ip']
        port = subscript['port']
        subsurl = subscript['url']
        destination = (ip, int(port))
        _state = _self.state
        message = ("HTTP/1.1 200 OK\r\n"
                   "SID: uuid:Socket-1_0-%s_sub0000000060\r\n"
                   "TIMEOUT: Second-3100\r\n"
                   "Server: Pi-Linux/Wheezy, UPnP/1.1, Py-Wemo/0.9\r\n"
                   "Content-Length: 0\r\n"
                   "CONNECTION: close\r\n"
                   "\r\n" % _self.serial )
        _dbg(0,"Sending Renew-Subscr to %s:%s /%s for %s" % (ip, port, subsurl, _self.name))
        _dbg(2,"%s" % message)
        _tmpsock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
          _tmpsock.connect(destination)
          _tmpsock.send(message)
        except Exception, e:
          if int(e[0]) == 111:
            _dbg(0,"Skipping Error %s" % e[1])
          else:
            _dbg(0,"Failed to send Notify with: %s" % e)
        _tmpsock.shutdown(socket.SHUT_RDWR)
        _tmpsock.close()
        del(_tmpsock)

    def __init__(self, name, listener, poller, ip_address, port, action_handler = None, dev_type = 'controllee'):
        self.serial = self.make_uuid(name)
        self.name = name
        self.ip_address = ip_address
        self.dev_type = dev_type
        self.subsfile = "sub_l_%s" % name.replace(' ', '_')
        self.seq = 0
        self.state = 0
        persistent_uuid = "Socket-1_0-" + self.serial
        _fh = open(_tmpDir + self.subsfile + ".pkl", "a")
        _fh.close
        other_headers = ['X-User-Agent: redsonic']
        upnp_device.__init__(self, listener, poller, port, "http://%(ip_address)s:%(port)s/setup.xml", "Unspecified, UPnP/1.0, Unspecified", persistent_uuid, other_headers=other_headers, ip_address=ip_address)
        if action_handler:
            self.action_handler = action_handler
        else:
            self.action_handler = self
        _dbg(0,"FauxMo device '%s' ready on %s:%s" % (self.name, self.ip_address, self.port))

    def get_name(self):
        return self.name

    def handle_request(self, data, sender, socket):
        global _inUpdate
        _dbg(1,"Handling req. from %s:%s" % (socket.getpeername()))
        _dbg(2,"Received socket data: \"%s\"" % data)
        if data.find('GET /setup.xml HTTP/1.1') == 0:
            _dbg(0, "Responding to setup.xml for %s" % self.name)
            xml = SETUP_XML % {'device_type' : self.dev_type, 'device_name' : self.name, 'device_port' : self.port, 'device_serial' : self.serial}
            date_str = email.utils.formatdate(timeval=None, localtime=False, usegmt=True)
            message = ("HTTP/1.1 200 OK\r\n"
                       "CONTENT-LENGTH: %d\r\n"
                       "CONTENT-TYPE: text/xml\r\n"
                       "DATE: %s\r\n"
                       "LAST-MODIFIED: Sat, 01 Jan 2000 00:01:15 GMT\r\n"
                       "SERVER: Unspecified, UPnP/1.0, Unspecified\r\n"
                       "X-User-Agent: redsonic\r\n"
                       "CONNECTION: close\r\n"
                       "\r\n"
                       "%s" % (len(xml), date_str, xml))
            socket.send(message)
        elif data.find('GET /eventservice.xml HTTP/1.1') != -1:
            _dbg(0,"Responding to eventservice.xml for %s" % self.name)
            xml = EVENTSERVICE_XML % {}
            date_str = email.utils.formatdate(timeval=None, localtime=False, usegmt=True)
            message = ("HTTP/1.1 200 OK\r\n"
                       "CONTENT-LENGTH: %d\r\n"
                       "CONTENT-TYPE: text/xml\r\n"
                       "DATE: %s\r\n"
                       "LAST-MODIFIED: Sat, 01 Jan 2000 00:01:15 GMT\r\n"
                       "SERVER: Unspecified, UPnP/1.0, Unspecified\r\n"
                       "X-User-Agent: redsonic\r\n"
                       "CONNECTION: close\r\n"
                       "\r\n"
                       "%s" % (len(xml), date_str, xml))
            socket.send(message)
        elif data.find('GET /rulesservice.xml HTTP/1.1') != -1:
          _dbg(0,"Responding to rulesservice.xml for %s" % self.name)
          _fh = open("/etc/wemos/rulesservice.xml","r")
          xml = _fh.read()
          _fh.close()
          date_str = email.utils.formatdate(timeval=None, localtime=False, usegmt=True)
          message = ("HTTP/1.1 200 OK\r\n"
                     "CONTENT-LENGTH: %d\r\n"
                     "CONTENT-TYPE: text/xml\r\n"
                     "DATE: %s\r\n"
                     "LAST-MODIFIED: Sat, 01 Jan 2000 00:01:15 GMT\r\n"
                     "SERVER: Unspecified, UPnP/1.0, Unspecified\r\n"
                     "X-User-Agent: redsonic\r\n"
                     "CONNECTION: close\r\n"
                     "\r\n"
                     "%s" % (len(xml), date_str, xml))
          socket.send(message)
        elif data.find('GET /deviceservice.xml HTTP/1.1') != -1:
          _dbg(0,"Responding to deviceservice.xml for %s" % self.name)
          _html='<html><body><h1>404 Not Found</h1></body></html>'
          message = ("HTTP/1.1 404 Not Found\r\n"
                     "CONTENT-LENGTH: %d\r\n"
                     "CONTENT-TYPE: text/html\r\n"
                     "SERVER: Unspecified, UPnP/1.0, Unspecified\r\n"
                     "CONNECTION: close\r\n"
                     "\r\n"
                     "%s" % (len(xml), _html))
          socket.send(message)
        elif data.find('SUBSCRIBE /upnp/event/basicevent1') != -1:
          _dbg(1, "Responding to Subscribe for %s by %s" % (self.name, socket.getpeername()))
          message = ("HTTP/1.1 200 OK\r\n"
                     "SID: uuid:Socket-1_0-%s_sub0000000060\r\n"
                     "TIMEOUT: Second-3100\r\n"
                     "Server: Pi-Linux/Wheezy, UPnP/1.1, Py-Wemo/0.9\r\n"
                     "Content-Length: 0\r\n"
                     "CONNECTION: close\r\n"
                     "\r\n" % self.serial )
          socket.send(message)
          # socket.close()
          if data.find('CALLBACK') != -1:
            _dbg(0, "New Subscribe for %s" % self.name)
            _dbg(1, data)
            _cbt = data[data.find('CALLBACK'):]
            _cbt = _cbt[:_cbt.find('>')]
            _cb, _cbc = _cbt.split()
            _cbc = _cbc[_cbc.find('//')+2:]
            _subs, _subsurl = _cbc.split('/')
            # ToDo: reset seq to 0/-1
            #   This is ugly - I have a hunch that seq should be per subscriber and not per device
            self.seq = 0
            self.update_subscription( _subs, _subsurl )
            send_event(self)
          else:
            _dbg(0, "Renew-Subscribe for %s to %s" % (self.name, socket.getpeername()))
          # socket.close()
        elif data.find('SOAPACTION: "urn:Belkin:service:basicevent:1#SetBinaryState"') != -1:
          _inUpdate=1
          _dbg(0,"Responding to set binary state from %s:%s" % socket.getpeername())
          success = False
          if data.find('<BinaryState>1</BinaryState>') != -1:
            # on
            _dbg(0,"Responding to ON for %s" % self.name)
            success = self.action_handler.on()
            if success:
              self.state = 1
            else:
              _dbg(0,"Couldn't set device ON")
          elif data.find('<BinaryState>0</BinaryState>') != -1:
            # off
            _dbg(0,"Responding to OFF for %s" % self.name)
            success = self.action_handler.off()
            if success:
              self.state = 0
            else:
              _dbg(0,"Couldn't set device OFF")
          else:
            _dbg(0,"Unknown Binary State request:")
            _dbg(0,data)
          if success:
            # The echo is happy with the 200 status code and doesn't
            # appear to care about the SOAP response body
            # soap = ""
            # But, FWIW, we'll stick to protocol ;) :
            _dbg(0,"SetBinaryState was successful, so let's send a response")
            soap = "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"><s:Body><u:SetBinaryStateResponse xmlns:u=\"urn:Belkin:service:basicevent:1\"><CountdownEndTime>0</CountdownEndTime></u:SetBinaryStateResponse></s:Body> </s:Envelope>"
            date_str = email.utils.formatdate(timeval=None, localtime=False, usegmt=True)
            message = ("HTTP/1.1 200 OK\r\n"
                       "CONTENT-LENGTH: %d\r\n"
                       "CONTENT-TYPE: text/xml; charset=\"utf-8\"\r\n"
                       "DATE: %s\r\n"
                       "EXT:\r\n"
                       "SERVER: Unspecified, UPnP/1.0, Unspecified\r\n"
                       "X-User-Agent: redsonic\r\n"
                       "CONNECTION: close\r\n"
                       "\r\n"
                       "%s" % (len(soap), date_str, soap))
            socket.send(message)
            # update_switches_state()
            send_event(self)
          else:
            _dbg(0,"SetBinaryState failed - no answer sent...")
          _inUpdate = 0
        elif data.find('SOAPACTION: "urn:Belkin:service:basicevent:1#GetBinaryState"') != -1:
          _dbg(0,"Responding to GetBinaryState for %s" % self.name)
          _dbg(1,"Debug: %s" % data)
          success = False
          update_switches_state()
          # _f=0
          # i=0
          # _st=-1
          # for _dev in _devices:
          #   if _dev[0] == self.name:
          #     _f=1
          #     _st=_devices[int(i)][1]
          #     _dbg(1,"Found tracked state at index %d to be %d" % (i, _st))
          #     break
          #   i += 1
          # _dbg(0,"Found tracked state at index %d to be %d" % (i, _st))
          soap = "<?xml version=\"1.0\" encoding=\"utf-8\"?><s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"><s:Body><u:GetBinaryState xmlns:u=\"urn:Belkin:service:basicevent:1\"><BinaryState>%d</BinaryState></u:GetBinaryState></s:Body></s:Envelope>" % self.state
          date_str = email.utils.formatdate(timeval=None, localtime=False, usegmt=True)
          message = ("HTTP/1.1 200 OK\r\n"
                     "CONTENT-LENGTH: %d\r\n"
                     "CONTENT-TYPE: text/xml charset=\"utf-8\"\r\n"
                     "DATE: %s\r\n"
                     "EXT:\r\n"
                     "SERVER: Unspecified, UPnP/1.0, Unspecified\r\n"
                     "X-User-Agent: redsonic\r\n"
                     "CONNECTION: close\r\n"
                     "\r\n"
                     "%s" % (len(soap), date_str, soap))
          socket.send(message)
        else:
          _dbg("Unknown Call: ")
          _dbg(data)

    def on(self):
        return False

    def off(self):
        return True

# Since we have a single process managing several virtual UPnP devices,
# we only need a single listener for UPnP broadcasts. When a matching
# search is received, it causes each device instance to respond.
#
# Note that this is currently hard-coded to recognize only the search
# from the Amazon Echo for WeMo devices. In particular, it does not
# support the more common root device general search. The Echo
# doesn't search for root devices.

class upnp_broadcast_responder(object):
    TIMEOUT = 0

    def __init__(self):
        self.devices = []

    def init_socket(self):
        ok = True
        self.ip = '239.255.255.250'
        self.port = 1900
        try:
            #This is needed to join a multicast group
            self.mreq = struct.pack("4sl",socket.inet_aton(self.ip),socket.INADDR_ANY)

            #Set up server socket
            self.ssock = socket.socket(socket.AF_INET,socket.SOCK_DGRAM,socket.IPPROTO_UDP)
            self.ssock.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)

            try:
                self.ssock.bind(('',self.port))
            except Exception, e:
                _dbg(0,"WARNING: Failed to bind %s:%d: %s" , (self.ip,self.port,e))
                ok = False

            try:
                self.ssock.setsockopt(socket.IPPROTO_IP,socket.IP_ADD_MEMBERSHIP,self.mreq)
            except Exception, e:
                _dbg(0,"WARNING: Failed to join multicast group: %s" % e)
                ok = False

        except Exception, e:
            _dbg(0,"Failed to initialize UPnP sockets: %s" % e)
            return False
        if ok:
            _dbg(0,"Listening for UPnP broadcasts")

    def fileno(self):
        return self.ssock.fileno()

    def do_read(self, fileno):
        data, sender = self.recvfrom(1024)
        if data:
          if data.find('M-SEARCH') == 0:
            if data.find('urn:Belkin:device:**') != -1:
              _dbg(0,"Found device from %s on port %s" % sender)
              _dbg(1,data)
              for device in self.devices:
                time.sleep(0.1)
                device.respond_to_search(sender, 'urn:Belkin:device:**')
            elif data.find('urn:Belkin:service:') != -1:
              _dbg(1,"Found service from %s on port %s" % sender)
              _dbg(2,data)
              for device in self.devices:
                time.sleep(0.1)
                device.respond_to_search(sender, 'urn:Belkin:service:basicevent:1')
            elif data.find('urn:Belkin') != -1:
              _dbg(0,"Found unhandled Belkin search")
              _dbg(0,data)
            else:
              _dbg(2,"Passing: ")
              _dbg(2,data)
              pass
        else:
          _dbg(0,"unhandled data:")
          _dbg(0,data)

    #Receive network data
    def recvfrom(self,size):
        if self.TIMEOUT:
            self.ssock.setblocking(0)
            ready = select.select([self.ssock], [], [], self.TIMEOUT)[0]
        else:
            self.ssock.setblocking(1)
            ready = True

        try:
            if ready:
                return self.ssock.recvfrom(size)
            else:
                return False, False
        except Exception, e:
            _dbg("In recvfrom socket not ready : %s" % e)
            return False, False

    def add_device(self, device):
        self.devices.append(device)
        _dbg(0, "UPnP broadcast listener: new device registered")


# This is an example handler class. The fauxmo class expects handlers to be
# instances of objects that have on() and off() methods that return True
# on success and False otherwise.
#
# This example class takes two full URLs that should be requested when an on
# and off command are invoked respectively. It ignores any return data.

class rest_api_handler(object):
    def __init__(self, on_cmd, off_cmd, query_cmd = ""):
        self.on_cmd = on_cmd
        self.off_cmd = off_cmd
        if query_cmd:
          self.query_cmd = query_cmd

    def on(self):
        r = requests.get(self.on_cmd)
        return r.status_code == 200

    def off(self):
        r = requests.get(self.off_cmd)
        return r.status_code == 200

    def can_query(self):
        if hasattr(self, 'query_cmd'):
          return True
        return False

    def query(self):
        try:
          if self.query_cmd != "":
            r = requests.get(self.query_cmd)
            _dbg(1,"Received status from query: \"%s\" content: \"%s\"" % (self.query_cmd, r.content.rstrip()))
            return r.content.rstrip()
          else:
            _dbg(0,"In rest_api_handler - found empty query_cmd on query")
            return -1
        except Exception, e:
          _dbg(0,"In rest_api_handler - query called, but no query_cmd set")
          return -1

    def len(self):
      _dbg(0,"In len of rest_api_handler")
      try:
        if self.query_cmd != "": return 3
      except Exception, e:
        _dbg(0,"Assuming len of 2")
        _dbg(3,"rest_api_handler.len through error: %s" % e)
        return 2

# Each entry is a list with the following elements:
#
# name of the virtual switch
# object with 'on','off' and optional 'query' methods
# port # (set to 0 to use a dynamic port)
# device-type (optional - will be set to 'controllee' if not set)

# NOTE: As of 2015-08-17, the Echo appears to have a hard-coded limit of
# 16 switches it can control. Only the first 16 elements of the FAUXMOS
# list will be used.
# http://192.168.1.21/ha-api?cmd=off&a=dining

FAUXMOS = [
    ['kitchen light', rest_api_handler(_lighturlbase + 'cmd=on&rel=3', _lighturlbase + 'cmd=off&rel=3', _lighturlbase + 'cmd=q&rel=3'),43003,'lightswitch'],
    ['dining light', rest_api_handler(_lighturlbase + 'cmd=on&rel=0', _lighturlbase + 'cmd=off&rel=0', _lighturlbase + 'cmd=q&rel=0'),43004,'lightswitch'],
    ['christmas light', rest_api_handler(_lighturlbase + 'cmd=on&rel=7', _lighturlbase + 'cmd=off&rel=7', _lighturlbase + 'cmd=q&rel=7'),43006,'lightswitch'],
    ['lounge light', rest_api_handler(_lighturlbase + 'cmd=on&rel=2', _lighturlbase + 'cmd=off&rel=2', _lighturlbase + 'cmd=q&rel=2'),43007,'lightswitch'],
    ['lightstrip light', rest_api_handler(_lighturlbase + 'cmd=on&rel=14', _lighturlbase + 'cmd=off&rel=14', _lighturlbase + 'cmd=q&rel=14'),43008,'lightswitch'],
    ['hedge sprinkler', rest_api_handler(_sprinklerurlbase + 'cmd=on&valve=0', _sprinklerurlbase + 'cmd=off&valve=0', _sprinklerurlbase + 'cmd=query&valve=0'),43020,'controllee'],
    ['shed sprinkler', rest_api_handler(_sprinklerurlbase + 'cmd=on&valve=1', _sprinklerurlbase + 'cmd=off&valve=1', _sprinklerurlbase + 'cmd=query&valve=1'),43021,'controllee'],
    ['Roomba', rest_api_handler('http://roombot/api?action=clean&value=start', 'http://roombot/api?action=dock&value=home'),0],
]

# for _dev in FAUXMOS:
#   _devices.append([_dev[0], 0])
# _dbg(1,"Device list: %s" % _devices)

if len(sys.argv) > 1 and sys.argv[1] == '-d':
    _DEBUG = 1

# Set up our singleton for polling the sockets for data ready
p = poller()

# Set up our singleton listener for UPnP broadcasts
u = upnp_broadcast_responder()
u.init_socket()

# Add the UPnP broadcast listener to the poller so we can respond
# when a broadcast is received.
p.add(u)
switches=[]

# Create our FauxMo virtual switch devices
for one_faux in FAUXMOS:
    if len(one_faux) == 3:
        # a device-type wasn't specified, use 'controllee'
        one_faux.append('controllee')
    switch = fauxmo(one_faux[0], u, p, None, one_faux[2], action_handler = one_faux[1], dev_type = one_faux[3])
    switches.append(switch)

_refresh_subs_time = time.time() + 300
update_switches_state()
signal.signal(signal.SIGUSR1, notify_handler)

_dbg(0,"Entering main loop\n")

while True:
    try:
        p.poll(100)
        # Allow time for a ctrl-c to stop the process
        # Since daemon, forget that
        time.sleep(0.1)
    except Exception, e:
      _dbg(0,"Error: %s" % (e))
      if int(e[0]) != 4 and int(e[0]) != 104:
        _dbg(0,"ErrNum: %s Reason: %s" % (e[0], e[1]))
        break
      else:
        _dbg(0,"Skipping Error: %d - \"%s\"" % (e[0], e[1]))
        pass
    if time.time() > _refresh_subs_time:
      _dbg(0, "Should refresh now")
      # for faux in switches:
      #   _dbg(0,"Refreshing %s" % faux.name)
      #   faux.renew_subscr()
      _refresh_subs_time = time.time() + 300
      _dbg(2,switches)

