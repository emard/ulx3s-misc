#!/usr/bin/env python3

import math

def checksum(x):
  s = 0
  for b in x:
    s += ord(b)
  return s & 0xFF

f = open("/tmp/circle.wav", "wb")
hdr  = b"RIFF" + bytearray([0x00, 0x00, 0x00, 0x00]) # chunk size bytes (len, including hdr), file growing, not yet known
hdr += b"WAVE"
# subchunk1: fmt
hdr += b"fmt " + bytearray([
    0x10, 0x00, 0x00, 0x00, # subchunk 1 size 16 bytes
    0x01, 0x00, # audio format = 1 (PCM)
    0x06, 0x00, # num channels = 6
    0xE8, 0x03, 0x00, 0x00, # sample rate = 1000 Hz
    0xE0, 0x2E, 0x00, 0x00, # byte rate = 12*1000 = 12000 byte/s
    0x0C, 0x00, # block align = 12 bytes
    0x10, 0x00]) # bits per sample = 16 bits
# subchunk2: data
hdr += b"data" + bytearray([0x00, 0x00, 0x00, 0x00]) # chunk size bytes (len), file growing, not yet known
if len(hdr) != 44:
  print("wrong wav header length=%d, should be 44" % len(hdr))
f.write(hdr)
sample = bytearray(12)
for y in range(360*10):
  x = abs(y-360*5)
  a = x # % 360
  r = 1.0 + 0.01*math.sin(y/10) # r imperfection
  latumin = int(30000000 + 200000 * r * math.cos(a*math.pi/180))
  lonumin = int(30000000 + 290000 * r * math.sin(a*math.pi/180))
  flip = 0
  if y < 360*5:
    flip = 180
  heading = (x+90+flip) % 360
  gps_data = "GPRMC,%02d%02d%02d.0,V,%02d%02d.%06d,N,%03d%02d.%06d,E,%06.2f,%05.1f,%02d%02d%02d,000.0,E,N" % (
    y//3600,y//60%60,y%60, # hms
    45,latumin//1000000,latumin%1000000,  # lat
    16,lonumin//1000000,lonumin%1000000,  # lon
    44.12, # kt
    heading,
    1,1,1  # dmy
  )
  iri100_data = ("L%05.2fR%05.2f" % (1.0, 1.0));
  iri20_data  = ("L%05.2fS%05.2f" % (1.0, 1.0));
  circle_tag  = " $%s*%02X %s*%02X %s*%02X " % (
    gps_data    , checksum(gps_data   ) ,
    iri100_data , checksum(iri100_data) ,
    iri20_data  , checksum(iri20_data )
  )
  #print(circle_tag)
  for b in circle_tag:
    c = ord(b)
    c &= 63
    for i in range(6):
      sample[2*i]=c&1
      c >>= 1
    f.write(sample)
f.close()
