#!/usr/bin/env python3

wavfile = "/media/guest/E9ED-92C5/accel.wav"
#wavfile = "/tmp/accel.wav"
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
  if(a != 32):
    c = a
    # convert control chars<32 to uppercase letters >=64
    if((a & 0x20) == 0):
      c ^= 0x40
    nmea.append(c)
    if(a == 33):
      x=i-prev_i
      if(x != 100):
        print(i,i-prev_corr_i,x,a)
        prev_corr_i = i
      prev_i = i
  else: # a == 32
    if(len(nmea)):
      print(i,nmea)
    nmea=bytearray(0)
  i += 1
