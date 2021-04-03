#!/usr/bin/env python3

# PPS proxy

# reads GPS PPS input from its CDC (cd) line
# sends PPS to ULX3S nRTS (ftdi_nrts) line

import serial, time

gps = serial.Serial()
gps.baudrate = 4800
#gps.port = '/dev/ttyUSB0'
gps.port = '/dev/rfcomm61'
gps.rtscts = False
gps.dsrdtr = False
gps.open()
gps.setDTR(1)
gps.setRTS(1) # value set here will appear inverted at ftdi_nrts, 0->1, 1->0

ulx = serial.Serial()
ulx.baudrate = 115200
ulx.port = '/dev/ttyUSB1'
ulx.open()

for i in range(10):
  print(gps.readline())

# workaround if no PPS signal

while True:
  r=gps.readline().decode("utf-8") 
  if r.startswith("$GPRMC"):
    if r[14]=="0":
      ulx.setRTS(0)
      time.sleep(0.1)
      ulx.setRTS(1)
      print(r)

while False:
  t=int(time.time())&1
  ulx.setRTS(t)
  print(t)
