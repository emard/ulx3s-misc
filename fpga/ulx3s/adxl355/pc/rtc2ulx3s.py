#!/usr/bin/env python3

# PPS proxy

# reads GPS PPS input from its CDC (cd) line
# sends PPS to ULX3S nRTS (ftdi_nrts) line

import serial, time

ulx = serial.Serial()
ulx.baudrate = 115200
ulx.port = '/dev/ttyUSB1'
ulx.open()

while True:
  t=int(time.time())&1
  ulx.setRTS(t)
  #print(t)
