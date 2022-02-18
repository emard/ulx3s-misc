#!/usr/bin/env python3

import sys
from functools import reduce
from operator import xor

wavfile = sys.argv[1]
# PPS tag appears as "!" in the data stream
show_pps = 0

f = open(wavfile, "rb");
f.seek(44+0*12)
b=bytearray(12)
mvb=memoryview(b)
i = 0
prev_i = 0
prev_corr_i = 0
nmea=bytearray(0)
while f.readinto(mvb):
  a=(b[0]&1) | ((b[2]&1)<<1) | ((b[4]&1)<<2) | ((b[6]&1)<<3) | ((b[8]&1)<<4) | ((b[10]&1)<<5)
  #if b[5]==0 or b[5]==255 or b[11]==0 or b[11]==255:
  #  print("glitch")
  if a != 32:
    c = a
    # convert control chars<32 to uppercase letters >=64
    if((a & 0x20) == 0):
      c ^= 0x40
    if a != 33 or show_pps:
      nmea.append(c)
    if a == 33 and show_pps:
      x=i-prev_i
      if(x != 100):
        print(i,i-prev_corr_i,x,a)
        prev_corr_i = i
      prev_i = i
  else: # a == 32
    if len(nmea):
      print(i,nmea.decode("utf-8"))
      if len(nmea)>4:
        crc = reduce(xor, map(int, nmea[1:-3]))
        hexcrc = bytearray(b"%02X" % crc)
        if nmea[-2:] != hexcrc:
          print("bad crc, expected %02X" % crc)
    nmea=bytearray(0)
  i += 1
