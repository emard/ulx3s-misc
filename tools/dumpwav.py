#!/usr/bin/env python3

f = open("accel.wav", "rb");
f.seek(44+0*12)
b=bytearray(12)
mvb=memoryview(b)
i = 0
prev_i = 0
while f.readinto(mvb):
  a=(b[0]&1) | ((b[2]&1)<<1) | ((b[4]&1)<<2) | ((b[6]&1)<<3) | ((b[8]&1)<<4) | ((b[10]&1)<<5) 
  if(a != 32):
    x=i-prev_i
    if(x != 100):
      print(i,x)
    prev_i = i
  i += 1
