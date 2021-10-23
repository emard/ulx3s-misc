#!/usr/bin/env python3

x = 15

while x > 1:
  print("%08X" % x)
  if (x & 1) != 0:
    x = (x*3+1)//2
  else:
    x = x//2
