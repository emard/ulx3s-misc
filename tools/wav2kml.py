#!/usr/bin/env python3

# apt install python3-fastkml python3-shapely python3-lxml

from fastkml import kml, styles
from shapely.geometry import Point, LineString, Polygon

import sys, colorsys

wavfile = sys.argv[1]
# PPS tag appears as "!" in the data stream
show_pps = 0

red_iri = 2.5

# input is NMEA string like "4500.112233,N,01500.112233,E"
def nmea_latlon2kml(ns):
    lat_deg=int(ns[0:2])
    lat_min=float(ns[2:11])
    lon_deg=int(ns[14:17])
    lon_min=float(ns[17:26])
    return (lon_deg+lon_min/60.0,lat_deg+lat_min/60.0,0)

# convert value 0-1 to rainbow color pink-red
# color 0=purple 0.2=blue 0.7=green 0.8=yellow 0.9=orange 1=red
# returns 0xAABBGGRR color32 format
def color32(color:float) -> int:
  if color < 0.0:
    color = 0.0
  if color > 1.0:
    color = 1.0
  # convert color to RGB
  (r,g,b) = colorsys.hsv_to_rgb((1.0001-color)*0.8332, 1.0, 1.0)
  return ( (0xf0 << 24) + (int(b*255)<<16) + (int(g*255)<<8) + (int(r*255)<<0) )
  #print("%f %f %f" % (r,g,b) )
  #print("%08x" % color32)

iri_left    = 0.0
iri_right   = 0.0
iri_avg     = 0.0
latlon      = None
latlon_prev = None

rarify = 0 # to rarify kml markers

k = kml.KML()
ns = '{http://www.opengis.net/kml/2.2}'
d = kml.Document(ns, 'docid', 'doc name', 'doc description')
f = kml.Folder(ns, 'fid', 'f name', 'f description')
k.append(d)
d.append(f)
nf = kml.Folder(ns, 'nested-fid', 'nested f name', 'nested f description')
f.append(nf)
f2 = kml.Folder(ns, 'id2', 'name2', 'description2')
d.append(f2)

arrow_icon_href="http://maps.google.com/mapfiles/kml/shapes/arrow.png"

# color AABBGGRR
# arrow heading: 0 down (south), 90 left (west), 180 up (north), 270 right (east)

#is0 = styles.IconStyle(ns, "id", color="FFFF7777", scale=1.0, heading=270.0, icon_href=arrow_icon_href)
#isty0 = styles.Style(styles = [is0])

#ls0 = styles.LineStyle(ns, color="00FF00FF", width=10)
#sty0 = styles.Style(styles = [ls0])

#ls1 = styles.LineStyle(ns, color="FF00FFFF", width=10)
#sty1 = styles.Style(styles = [ls1])

#ls2 = styles.LineStyle(ns, color="FF0000FF", width=10)
#sty2 = styles.Style(styles = [ls2])


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
        #print(i,i-prev_corr_i,x,a)
        prev_corr_i = i
      prev_i = i
  else: # a == 32
    if(len(nmea)):
      #print(i,nmea.decode("utf-8"))
      if nmea[0:6]==b"$GPRMC" and len(nmea)==79:
        latlon=nmea_latlon2kml(nmea[18:46])
        heading=float(nmea[54:59])
        if latlon_prev!=None:
          ls0 = styles.LineStyle(ns, color=("%08X" % color32(iri_avg/red_iri)), width=12)
          lsty0 = styles.Style(styles = [ls0])
          p1 = kml.Placemark(ns, 'id', name=("%.2f" % iri_avg), description=("L=%.2f R=%.2f" % (iri_left, iri_right)), styles=[lsty0])
          p1.geometry = LineString([latlon_prev, latlon])
          f2.append(p1)  
        latlon_prev = latlon
      if nmea[0:1]==b"L" and latlon!=None:
        rpos=nmea.find(b"R")
        iri_left=float(nmea[1:rpos])
        iri_right=float(nmea[rpos+1:])
        iri_avg=(iri_left+iri_right)/2
        rarify += 1
        if (rarify&31==0):
          is0 = styles.IconStyle(ns, "id", color=("%08X" % color32(iri_avg/red_iri)), scale=1.0, heading=(180+heading)%360, icon_href=arrow_icon_href)
          isty0 = styles.Style(styles = [is0])
          p0 = kml.Placemark(ns, 'id', name=("%.2f" % iri_avg), description=("L=%.2f R=%.2f" % (iri_left, iri_right)), styles=[isty0])
          p0.geometry = Point(latlon)
          f2.append(p0)
    # delete, consumed  
    nmea=bytearray(0)
  i += 1

#p0 = kml.Placemark(ns, 'id', '1.00', 'description', styles=[isty0])
#p0.geometry = Point([nmea2kml("4548.520609,N,01559.975552,E")])
#f2.append(p0)

#p1 = kml.Placemark(ns, 'id', 'name', 'description', styles=[sty1])
#p1.geometry = LineString([(0.1, 0.1, 0.1), (1, 1, 0)])
#f2.append(p1)

#p2 = kml.Placemark(ns, 'id', 'name', 'description', styles=[sty2])
#p2.geometry = LineString([(1, 1, 0), (1, 0, 1)])
#f2.append(p2)

print(k.to_string(prettyprint=True))
