#!/usr/bin/env python3

import math

f = open("/tmp/circle.wav", "wb")
hdr = bytearray(44)
f.write(hdr)
sample = bytearray(12)
for x in range(360*6):
  a = x % 360
  r = 1.0 + 0.01*math.sin(x/10) # r imperfection
  latumin = int(30000000 + 200000 * r * math.cos(a*math.pi/180))
  lonumin = int(30000000 + 290000 * r * math.sin(a*math.pi/180))
  heading = (a+90) % 360
  circle_tag = " $GPRMC,%02d%02d%02d.0,V,%02d%02d.%06d,N,%03d%02d.%06d,E,%03d.%02d,%05.1f,%02d%02d%02d,000.0,E,N*00 L%05.2fR%05.2f*00 " % (
    x//3600,x//60%60,x%60, # hms
    45,latumin//1000000,latumin%1000000,  # lat
    16,lonumin//1000000,lonumin%1000000,  # lon
    44,12,  # kt
    heading,
    1,1,1, # dmy
    1.0,1.0
  )
  print(circle_tag)
  for b in circle_tag:
    c = ord(b)
    c &= 63
    for i in range(6):
      sample[2*i]=c&1
      c >>= 1
    f.write(sample)
f.close()
