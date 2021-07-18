#!/usr/bin/env python3

# apt install python3-fastkml python3-shapely python3-lxml
# ./wav2kml.py 20210701.wav > 20210701.kml

from fastkml import kml, styles
from shapely.geometry import Point, LineString, Polygon
from sys import argv
from colorsys import hsv_to_rgb
from math import sqrt,sin,cos,asin,pi,ceil,atan2

wavfile = argv[1]

red_iri = 2.5 # colorization
mark_every = 25 # placemark every N GPS readings

# PPS tag appears as "!" in the data stream
show_pps = 0

# input is NMEA string like "4500.112233,N,01500.112233,E"
# output is (lon,lat) tuple
def nmea_latlon2kml(ns):
    lat_deg=int(ns[0:2])
    lat_min=float(ns[2:11])
    lon_deg=int(ns[14:17])
    lon_min=float(ns[17:26])
    return (lon_deg+lon_min/60.0,lat_deg+lat_min/60.0)

# helper function for distance
def haversin(theta:float) -> float:
  return sin(0.5*theta)**2

# input ( lat1,lon1, lat2,lon2 ) degrees
# output distance in meters
def distance(lat1:float, lon1:float, lat2:float, lon2:float) -> float:
  R=6371.0008e3 # m Earth volumetric radius
  # convert to radians
  lat1 *= pi/180.0
  lon1 *= pi/180.0
  lat2 *= pi/180.0
  lon2 *= pi/180.0
  deltalat=lat2-lat1
  deltalon=lon2-lon1
  h=haversin(deltalat)+cos(lat1)*cos(lat2)*haversin(deltalon)
  dist=2*R*asin(sqrt(h))
  return dist

# convert value 0-1 to rainbow color pink-red
# color 0=purple 0.2=blue 0.7=green 0.8=yellow 0.9=orange 1=red
# returns 0xAABBGGRR color32 format
def color32(color:float) -> int:
  if color < 0.0:
    color = 0.0
  if color > 1.0:
    color = 1.0
  # convert color to RGB
  (r,g,b) = hsv_to_rgb((1.0001-color)*0.8332, 1.0, 1.0)
  return ( (0xf0 << 24) + (int(b*255)<<16) + (int(g*255)<<8) + (int(r*255)<<0) )
  #print("%f %f %f" % (r,g,b) )
  #print("%08x" % color32)

segment_m   = 100.0 # m
discontinuety_m = 50.0 # m don't draw lines longer than this

# timespan is required for kml LookAt
# here we reset it and track while reading
time_1st    = None
time_last   = None

k = kml.KML()
ns = '{http://www.opengis.net/kml/2.2}'
d = kml.Document(ns, id='docid', name='doc name', description='description')
f = kml.Folder(ns, 'fid', 'f name', 'f description')
k.append(d)
d.append(f)
nf = kml.Folder(ns, 'nested-fid', 'nested f name', 'nested f description')
f.append(nf)
f2 = kml.Folder(ns, 'id2', 'name2', 'description2')
d.append(f2)
t = kml.TimeStamp()

arrow_icon_href="http://maps.google.com/mapfiles/kml/shapes/arrow.png"

# buffer to read wav
b=bytearray(12)
mvb=memoryview(b)

for wavfile in argv[1:]:
  f = open(wavfile, "rb");
  f.seek(44+0*12)
  i = 0 # for PPS signal tracking
  prev_i = 0
  prev_corr_i = 0
  # state parameters for drawing on the map
  iri_left    = 0.0
  iri_right   = 0.0
  iri_avg     = 0.0
  lonlat      = None
  lonlat_prev = None
  lonlat_diff = None
  lonlat_1st  = None
  speed_kt    = 0.0
  speed_kmh   = 0.0
  kmh_min     = 999.9
  kmh_max     = 0.0
  heading_prev = None
  travel      = 0.0 # m
  travel_next = 0.0 # m
  # set nmea line empty before reading
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
        if nmea.find(b'#') >= 0: # discontinuety, reset travel
          travel = 0.0
          travel_next = 0.0
        elif nmea[0:6]==b"$GPRMC" and (len(nmea)==79 or len(nmea)==68): # 68 is lost signal, tunnel mode
          if len(nmea)==79: # normal mode with signal
            lonlat=nmea_latlon2kml(nmea[18:46])
            tunel = 0
          elif len(nmea)==68: # tunnel mode without signal, keep heading
            if lonlat_diff:
              lonlat = ( lonlat[0] + lonlat_diff[0], lonlat[1] + lonlat_diff[1] )
            tunel = 11 # number of chars in shorter nmea sentence for tunnel mode
          if lonlat_1st == None:
            lonlat_1st = lonlat
          datetime=b"20"+nmea[64-tunel:66-tunel]+b"-"+nmea[62-tunel:64-tunel]+b"-"+nmea[60-tunel:62-tunel]+b"T"+nmea[7:9]+b":"+nmea[9:11]+b":"+nmea[11:15]+b"Z"
          if time_1st == None:
            time_1st = datetime
          if tunel == 0:
            heading=float(nmea[54:59])
            speed_kt=float(nmea[47:53])
          speed_kmh=speed_kt*1.852
          if speed_kmh > kmh_max:
            kmh_max = speed_kmh
          if speed_kmh < kmh_min:
            kmh_min = speed_kmh
          if lonlat_prev:
            dist_m = distance(lonlat_prev[1], lonlat_prev[0], lonlat[1], lonlat[0])
            travel += dist_m
            if dist_m < discontinuety_m: # don't draw too long lines
              ls0 = styles.LineStyle(ns,
                color=("%08X" % color32(iri_avg/red_iri)), width=6)
              lsty0 = styles.Style(styles = [ls0])
              p1 = kml.Placemark(ns, 'id',
                name=("%.2f" % iri_avg),
                description=("L=%.2f R=%.2f\n%.1f km/h\n%s" % (iri_left, iri_right, speed_kmh, datetime.decode("utf-8"))),
                styles=[lsty0])
              #p1_iri_left  = kml.Data(name="IRI_LEFT" , display_name="IRI_LEFT" , value="%.2f" % iri_left )
              #p1_iri_right = kml.Data(name="IRI_RIGHT", display_name="IRI_RIGHT", value="%.2f" % iri_right)
              #p1.extended_data = kml.UntypedExtendedData(elements=[p1_iri_left, p1_iri_right])
              p1.geometry = LineString([lonlat_prev, lonlat])
              t.timestamp, dummy = t.parse_str(datetime) # "2021-07-03T11:22:33Z"
              p1.timeStamp = t.timestamp
              f2.append(p1)
            else: # discontinuety, reset travel
              travel = 0.0
              travel_next = 0.0
          if lonlat_prev:
            lonlat_diff = ( lonlat[0] - lonlat_prev[0], lonlat[1] - lonlat_prev[1] )
          lonlat_prev = lonlat
        elif nmea[0:1]==b"L" and lonlat!=None:
          rpos=nmea.find(b"R")
          epos=nmea.find(b'*')
          if epos < 0:
            epos=nmea.find(b' ')
          try:
            iri_left=float(nmea[1:rpos])
            iri_right=float(nmea[rpos+1:epos])
          except:
            pass
          iri_avg=(iri_left+iri_right)/2
          if travel > travel_next:
            while travel > travel_next:
              travel_next += segment_m
            is0 = styles.IconStyle(ns, "id",
              color=("%08X" % color32(iri_avg/red_iri)),
              scale=1.0,
              heading=(180+heading)%360,
              icon_href=arrow_icon_href)
            isty0 = styles.Style(styles = [is0])
            p0 = kml.Placemark(ns, 'id',
              name=("%.2f" % iri_avg),
              description=("L=%.2f R=%.2f\n%.1f km/h (%.1f-%.1f km/h)\n%s" % (iri_left, iri_right, speed_kmh, kmh_min, kmh_max, datetime.decode("utf-8"))),
              styles=[isty0])
            p0.geometry = Point(lonlat)
            p0.timeStamp = t.timestamp
            f2.append(p0)
            kmh_max = 0.0
            kmh_min = 999.9
      # delete, consumed
      nmea=bytearray(0)
    i += 1
  f.close()
time_last = datetime

# output to string with hard-replace "visibility" to add LookAt tag
print(k.to_string(prettyprint=True).replace(
  "<visibility>1</visibility>",
  "<visibility>1</visibility>\n\
    <LookAt>\n\
      <longitude>%f</longitude>\n\
      <latitude>%f</latitude>\n\
      <heading>0</heading>\n\
      <tilt>0</tilt>\n\
      <range>2000</range>\n\
      <altitudeMode>relativeToGround</altitudeMode>\n\
      <TimeSpan>\n\
        <begin>%s</begin>\n\
        <end>%s</end>\n\
      </TimeSpan>\n\
    </LookAt>" % (lonlat_1st[0], lonlat_1st[1], time_1st.decode("utf-8"), time_last.decode("utf-8"))
))
