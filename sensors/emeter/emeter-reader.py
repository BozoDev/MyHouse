#!/usr/bin/env python
# -*- coding: utf_8 -*-

import sys, getopt, struct, serial
# from sys import argv

import modbus_tk
import modbus_tk.defines as cst
from modbus_tk import modbus_rtu

#PORT = 1
PORT = '/dev/ttyUSB0'
BAUD = 2400
SLAVE=2

def main(argv):
  vals=3
  startReg=0
  verbose=0
  try:
    opts, args = getopt.getopt(argv,"hvr:s:",["regs=","startReg=","help","verbose"])
  except getopt.GetoptError:
    print 'emeter-reader.py [-r 3/--regs=3] [-s 0/--startReg=0] [-v] [-h]'
    sys.exit(2)
  for opt, arg in opts:
    if opt in ("-h", "--help"):
      print 'emeter-reader.py [-h/--help] [-v/--verbose] [-r 3/--regs=3] [-s 0/--startReg=0]'
      sys.exit()
    elif opt in ("-r", "--regs"):
      vals = int(arg)
    elif opt in ("-s", "--startReg"):
      startReg = int(arg)
    elif opt in ("-v", "--verbose"):
      verbose=1
  if verbose == 1:
    print("Starting at reg: %s and will return %s values" % (startReg, vals))
    logger = modbus_tk.utils.create_logger("console")

  try:
    #Connect to the slave
    master = modbus_rtu.RtuMaster(
      serial.Serial(port=PORT, baudrate=BAUD, bytesize=8, parity='N', stopbits=1, xonxoff=0)
    )
    master.set_timeout(5.0)
    if verbose == 1:
      master.set_verbose(True)
      logger.info("connected")
    r=master.execute(SLAVE, cst.READ_INPUT_REGISTERS, startReg, vals * 2)
    for i in range(0, vals):
      a=struct.pack(">HH", r[i*2], r[i*2+1])
      b=struct.unpack('>f', a)
      print("%f" % b)
  except modbus_tk.modbus.ModbusError as exc:
    logger.error("%s- Code=%d", exc, exc.get_exception_code())
  master.close
    
if __name__ == "__main__":
  main(sys.argv[1:])


