#!/usr/bin/env python3

import math, struct

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
tag = "" # tag queue string starts as empty
# 1 kHz sample rate: samples count for 12 minutes driving
nsamples = 12*60*1000
for i in range(nsamples):
  sample = bytearray(struct.pack("<hhhhhh", 
    int(1000*math.sin(i/20)), int(1000*math.sin(i/30)), int(1000*math.sin(i/40)), 
    int(1000*math.sin(i/20)), int(1000*math.sin(i/30)), int(1000*math.sin(i/40))
  ))
  if i % 200 == 0: # every 0,2 seconds
    angle = i//200
    angle_bidirectional = abs(angle-360*5)
    angle_imperfection = angle_bidirectional # % 360
    r = 500.0 + 5.0*math.sin(angle/10) # [m] + imperfection (radius)
    x = r * math.sin(angle_imperfection*math.pi/180)
    y = r * math.cos(angle_imperfection*math.pi/180)
    lonumin = int(30000000 + 768 * x) # EW direction
    latumin = int(30000000 + 540 * y) # NS direction
    flip = 0
    if angle < 360*5:
      flip = 180
    heading = (angle_bidirectional+90+flip) % 360
    gps_data = "GPRMC,%02d%02d%02d.0,V,%02d%02d.%06d,N,%03d%02d.%06d,E,%06.2f,%05.1f,%02d%02d%02d,000.0,E,N" % (
      angle//3600,angle//60%60,angle%60, # hms
      45,latumin//1000000,latumin%1000000,  # lat
      16,lonumin//1000000,lonumin%1000000,  # lon
      43.2, # kt (43.2 kt = 80 km/h)
      heading,
      1,1,1  # dmy
    )
    iri100_data = ("L%05.2fR%05.2f" % (1.0+1.0*angle/3600, 1.0+1.0*angle/3600));
    iri20_data  = ("L%05.2fS%05.2f" % (1.0+1.0*angle/3600, 1.0+1.0*angle/3600));
    circle_tag  = " $%s*%02X %s*%02X %s*%02X " % (
      gps_data    , checksum(gps_data    ) ,
      iri100_data , checksum(iri100_data ) ,
      iri20_data  , checksum(iri20_data  )
    )
    tag += circle_tag
  c = 32 # space is default if queue is empty
  if len(tag): # queue has data
    c = ord(tag[0]) # ascii value of the first char
    c &= 63
    tag = tag[1:] # delete consumed first char
  # mix text tags into the samples
  for j in range(6):
    sample[2*j]=(sample[2*j]&0xFE)|(c&1)
    c >>= 1
  f.write(sample)
f.close()
