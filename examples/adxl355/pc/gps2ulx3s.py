#!/usr/bin/env python3

# PPS proxy

# reads GPS PPS input from its CDC (cd) line
# sends PPS to ULX3S nRTS (ftdi_nrts) line

import serial, time

gps = serial.Serial()
gps.baudrate = 4800
gps.port = '/dev/ttyUSB0'
gps.rtscts = True
gps.dsrdtr = True
gps.open()
gps.setDTR(True)
gps.setRTS(True)

ulx = serial.Serial()
ulx.baudrate = 115200
ulx.port = '/dev/ttyUSB1'
ulx.open()

while True:
  while(gps.cd):
    pass
  ulx.setRTS(0)
  print(0)
  while(not gps.cd):
    pass
  ulx.setRTS(1)
  print(1)

while False:
  ulx.setRTS(int(time.time())&1)
