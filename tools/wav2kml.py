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

def heading2(p1, p2):
  lon1,lat1=[a*pi/180.0 for a in p1]
  lon2,lat2=[a*pi/180.0 for a in p2]
  # Heading = atan2(cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(lon2-lon1), sin(lon2-lon1)*cos(lat2))
  Heading = atan2(cos(lon1)*sin(lon2)-sin(lon1)*cos(lon2)*cos(lat2-lat1), sin(lat2-lat1)*cos(lon2))
  return Heading*180.0/pi

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

gps_list = list()
# ((1234, "2021T15Z", (16,44), 80.0, 90.0), ...)
# named constant indexes in gps list
gps_seek      = 0
gps_datetime  = 1
gps_lonlat    = 2
gps_speed_kmh = 3
gps_heading   = 4
gps_iril      = 5
gps_irir      = 6

class snap:
  def __init__(self):
    # cut data into segment length [m]
    segment_length = 100.0    # [m]
    segment_snap   =   9.0    # [m]
    start_length   =   0.0    # analyze from this length [m]
    stop_length    =   1.0e9  # analyze up to this length [m]

    self.segment_length = segment_length
    
    self.init_gps_tracking()
    self.init_snap_segments()

    # multiple passes over the
    # same track will snap to same points
    # use 0 or negative segment_snap to disable snapping
    self.segment_snap = segment_snap

    self.start_length = start_length
    self.stop_length = stop_length

  def init_gps_tracking(self):
    # sample realtime tracking
    # after each discontinuity or segment length
    # we will reset sampletime. from then on,
    # sample rate increments should be added
    # don't initialize to 0 here, stamp_find_gaps has done it correctly
    # self.sample_realtime = 0.0
    # associative array for gps entries
    # self.next_gps = { "timestamp" : 0.0, "latlon" : (), "speed" : 0.0 }
    # (seek, timestamp, lonlat, speed_kmh, heading, iril, irir),
    self.next_gps = ( (0, None, (), 0.0, 0.0, 0.0, 0.0), )
    self.prev_gps = self.next_gps
    # self.prev_prev_gps = self.next_gps
    # track length up to prev_gps coordinate in [m]
    self.prev_gps_track_length = 0.0
    # current gps segment length
    self.current_gps_segment_length = 0.0
    # track length at which next length-based cut will be done
    self.cut_at_length = self.prev_gps_track_length + self.segment_length


  def init_snap_segments(self):
    # empty snap lists
    # consits of latlon and timestamp
    #self.snap_list = list()
    # snap list as associative array (indexed by directonal_index)
    self.snap_aa = {}
    # cut list is larger than snap list,
    # it contains each segment cut to be applied
    self.cut_list = list()

  # walk thru all gps data, create list of interpolated
  # equidistant points and snap to them when traveling again
  # over the same path
  # length = segment length [m] track will be divided into segments 
  #          of this length
  # snap = snap distance [m] when two parts of a track come togheter
  #        closer than this value, they will "snap" into the
  #        same spatial point. This value should be less than segment
  #        length and about equal or larger than GPS accuracy.
  # creates a list of new points to snap
  # when new point is considered, existing list is searched
  # if the point can somewhere otherwise it is placed as a new point
  def snap_segments(self):
    # print("Snapping to %.1f m segments, snap distance: %.1f m" % (length, snap))
    #self.init_gps_tracking()
    # rewind the gps filehandle to start from beginning
    gps_i = 0 # reset index of gps data (sequential reading)

    # search for nearest snap point
    distance_m = None
    nearest_index = None
    nearest_point = None

    # finite state machine to search for a snap point    
    snapstate = 0
    
    self.next_gps = None
    
    # intialize first cut
    self.cut_at_length = self.start_length

    while True:
      if gps_i < len(gps_list):
        gps = gps_list[gps_i]
        gps_i += 1
      else:
        break;
      # add to the track length using great circle formula
      # prev_prev_gps_track_length = self.prev_gps_track_length
      self.prev_gps_track_length += self.current_gps_segment_length
      self.prev_gps = self.next_gps
      self.next_gps = gps
      if self.prev_gps == None:
        self.prev_gps = self.next_gps
      # current length (between prev_gps and next_gps)
      # using haversin great circle formula
      if self.next_gps[gps_datetime] != None and self.prev_gps[gps_datetime] != None:
        self.current_gps_segment_length = \
          distance(self.prev_gps[gps_lonlat][1], self.prev_gps[gps_lonlat][0], self.next_gps[gps_lonlat][1], self.next_gps[gps_lonlat][0])

      # search snap list, compare latlon only.
      # find the nearest element (great circle)
      # if an element is found within snap [m] then
      # enter snap mode - in following data,
      # find the closest point - snap point
      prev_distance = distance_m
      prev_nearest_index = nearest_index
      prev_nearest_point = nearest_point
      distance_m = None
      nearest_index = None
      nearest_point = None
      index = 0
      for index,snap_point in self.snap_aa.items():
        #print(snap_point)
        new_distance = distance(snap_point["lonlat"][1], snap_point["lonlat"][0], self.next_gps[gps_lonlat][1], self.next_gps[gps_lonlat][0])
        # don't consider latest point as snap point
        # if index < len(self.snap_list)-0:
          # find the nearest distance and its list index
        if distance_m == None or new_distance < distance_m:
            distance_m = new_distance
            nearest_index = index
            # current point along the track
            nearest_point = self.next_gps
        #index += 1
      cut_index = index # if we don't find nearest previous point, cut to a new point
      if nearest_index != None:
        # print("nearest index ", nearest_index, " distance: ", distance)
        
        # calculate nearest_heading
        nearest_heading = self.snap_aa[nearest_index]["heading"]

        # states of the snap
        # 0. no snap, searching for a close point
        # 1. found point within snap distance
        # or successfully falling towards the same snap point
        # 2. past the snap, we must exit the snap distance
        # When it is rising, we know that we have passed the snap point,
        # so TODO: interpolate back in the current gps path to find the
        # closest point near the snap point - reset the segment length too
        if snapstate == 0:
          if distance_m < self.segment_snap:
            # found a point within snap range
            if distance_m < prev_distance:
              snapstate = 1 # approaching a snap point
        elif snapstate == 1:
          if distance_m > prev_distance:
            # distance is rising, we are receding from snap point
            snapstate = 2 # wait to completely exit this snap area
            # we are receding from the point
            # assume prev index was the closest
            # and prev nearest point is the point!
            # force the cut,
            # calculate approximate cut position
            cut_index = nearest_index
            if prev_nearest_index != None and prev_nearest_index == nearest_index:
              # approximately project point to track
              self.cut_at_length = self.prev_gps_track_length + self.current_gps_segment_length * prev_distance / (prev_distance + distance_m)
            else:
              self.cut_at_length = self.prev_gps_track_length + self.current_gps_segment_length - 1.0e-3
            #print("snap to ", self.cut_at_length)
        elif snapstate >= 2:
          if distance_m > self.segment_snap:
            snapstate = 0
      else:
        # no nearest index -> snap state = 0
        snapstate = 0
 
      # if not found in the snap list:
      # add to the length
      # and when the length is exceeded then interpolate
      # to cut for exactly length [m] segments and add this to
      # snap list
      if snapstate != 1: # if not near any snap point
       while self.prev_gps_track_length + self.current_gps_segment_length >= self.cut_at_length:
        # simplify code - don't interpolate
        #tp = [ self.prev_gps_track_length, self.prev_gps_track_length + self.current_gps_segment_length ]
        #yp = [ [ self.prev_gps[gps_lonlat][0], self.next_gps[gps_lonlat][0] ],
        #       [ self.prev_gps[gps_lonlat][1], self.next_gps[gps_lonlat][1] ],
        #       [ self.prev_gps[gps_timestamp], self.next_gps[gps_timestamp] ] ]
        #yi = [ numpy.interp(self.cut_at_length, tp, y) for y in yp ]
        #heading_deg = heading2(self.prev_gps[gps_lonlat], self.next_gps[gps_lonlat])
        heading_deg = self.prev_gps[gps_heading]
        # 0-90 and 270-360 is normal heading
        # 90-270 is reverse heading
        direction = 1
        if nearest_index != None and snapstate == 2:
          heading_difference = ((heading_deg - nearest_heading) % 360)
          # print "heading difference %.02f %.02f" % (heading, nearest_heading)
          if heading_difference > 90 and heading_difference < 270:
            direction = -1
        else:
          nearest_heading = heading_deg
        #if direction < 0:
        #  print "found reverse heading index %d" % cut_index
        if nearest_index != None:
          segment_index = nearest_index
        else:
          segment_index = index
        directional_index = (cut_index + 1) * direction
        cut_point = {
          "directional_index" : directional_index,
          "snapstate" : snapstate,
          "lonlat"    : self.next_gps[gps_lonlat],
          "heading"   : nearest_heading, # heading of the first cut
          "timestamp" : self.next_gps[gps_datetime],
          "length"    : self.cut_at_length,
          "iri_left"  : self.next_gps[gps_iril],
          "iri_right" : self.next_gps[gps_irir],
          }
        # print nearest_heading,heading
        # print snapstate
        # only small number of points are snap points 
        if snapstate != 2:
          #self.snap_list.append(cut_point)
          self.snap_aa[directional_index] = cut_point
        # cut point is each point along the track
        self.cut_list.append(cut_point)
        self.cut_at_length += self.segment_length
        # we should leave snap distance before
        # looking for the next snap point
        snapstate = 3

    # from snap list generate segment list with similar headings

    # before return
    # rewind the gps filehandle to start from beginning
    #self.gps_filehandle.seek(0)
    #self.init_gps_tracking()
    self.next_snap_index = 0
    self.next_cut_index = 0
    gps_i = 0
    # print self.snap_list
    # print self.cut_list
    #print("Snap: %d segment cuts to %d snap points" % (len(self.cut_list), len(self.snap_list)))

  def statistics(self):
    # convert snap list to associative array
    # add fields for statistics, reset to 0
    for key,value in self.snap_aa.items():
      self.snap_aa[key]["n"]          = 0
      self.snap_aa[key]["sum1_left"]  = 0.0
      self.snap_aa[key]["sum2_left"]  = 0.0
      self.snap_aa[key]["avg_left"]   = 0.0
      self.snap_aa[key]["std_left"]   = 0.0
      self.snap_aa[key]["sum1_right"] = 0.0
      self.snap_aa[key]["sum2_right"] = 0.0
      self.snap_aa[key]["avg_right"]  = 0.0
      self.snap_aa[key]["std_right"]  = 0.0
    # statistics sums
    for cut_point in self.cut_list:
      key = cut_point["directional_index"]
      # FIXME some keys doen't exist
      try:
        self.snap_aa[key]["n"]           += 1
        self.snap_aa[key]["sum1_left"]   += cut_point["iri_left"]
        self.snap_aa[key]["sum2_left"]   += cut_point["iri_left"]*cut_point["iri_left"]
        self.snap_aa[key]["sum1_right"]  += cut_point["iri_right"]
        self.snap_aa[key]["sum2_right"]  += cut_point["iri_right"]*cut_point["iri_right"]
      except:
        pass
    # average and standard dev
    for key,value in self.snap_aa.items():
      n = self.snap_aa[key]["n"]
      if n > 0:
        sum1_left  = self.snap_aa[key]["sum1_left"]
        sum2_left  = self.snap_aa[key]["sum2_left"]
        sum1_right = self.snap_aa[key]["sum1_right"]
        sum2_right = self.snap_aa[key]["sum2_right"]
        self.snap_aa[key]["avg_left"]  = sum1_left/n
        self.snap_aa[key]["avg_right"] = sum1_right/n
        self.snap_aa[key]["std_left"]  = abs( n*sum2_left  - sum1_left  * sum1_left  )**0.5/n
        self.snap_aa[key]["std_right"] = abs( n*sum2_right - sum1_right * sum1_right )**0.5/n

segment_m   = 100.0 # m
discontinuety_m = 50.0 # m don't draw lines longer than this

# timespan is required for kml LookAt
# here we reset it and track while reading
datetime    = None
time_1st    = None
time_last   = None
lonlat_1st  = None

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
  f = open(wavfile, "rb")
  seek = 44+0*12
  f.seek(seek)
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
    seek += 12 # bytes per sample
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
                description=("L=%.2f mm/m\nR=%.2f mm/m\nv=%.1f km/h\n%s" % (iri_left, iri_right, speed_kmh, datetime.decode("utf-8"))),
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
          # disabled placemarks arrows here
          # placed later from statistics
          #if travel > travel_next:
          #  while travel > travel_next:
          #    travel_next += segment_m
          #  is0 = styles.IconStyle(ns, "id",
          #    color=("%08X" % color32(iri_avg/red_iri)),
          #    scale=0.7,
          #    heading=(180+heading)%360,
          #    icon_href=arrow_icon_href)
          #  isty0 = styles.Style(styles = [is0])
          #  p0 = kml.Placemark(ns, 'id',
          #    # name=("%.2f" % iri_avg),
          #    description=("L=%.2f mm/m\nR=%.2f mm/m\n%.1f km/h (%.1f-%.1f km/h)\n%s" % (iri_left, iri_right, speed_kmh, kmh_min, kmh_max, datetime.decode("utf-8"))),
          #    styles=[isty0])
          #  p0.geometry = Point(lonlat)
          #  p0.timeStamp = t.timestamp
          #  f2.append(p0)
          #  kmh_max = 0.0
          #  kmh_min = 999.9
          # append to GPS list
          gps_list.append((seek, datetime, lonlat, speed_kmh, heading, iri_left, iri_right))
      # delete, consumed
      nmea=bytearray(0)
    i += 1
  f.close()
if datetime:
  time_last = datetime

# at this point gps_list is filled with all GPS readings
# snap to 100m segments
if True:
  snp = snap()
  snp.snap_segments()
  snp.statistics()

  # debug: placemarks from individual masurements in the cut_list
  # (those from which stat was calculated)
  if False:
   for pt in snp.cut_list: # every one for statistics
    flip_heading = 0
    if pt["directional_index"] < 0:
      flip_heading = 180;
    iri_avg = (pt["iri_left"] + pt["iri_right"]) / 2
    is0 = styles.IconStyle(ns, "id",
              color=("%08X" % color32(iri_avg/red_iri)),
              scale=0.7,
              heading=(180+pt["heading"]+flip_heading)%360,
              icon_href=arrow_icon_href)
    isty0 = styles.Style(styles = [is0])
    p0 = kml.Placemark(ns, 'id',
              name=("%.2f" % iri_avg),
              description=("L=%.2f mm/m\nR=%.2f mm/m\ndir_ind=%d\nsnapstate=%d" %
                (pt["iri_left"], pt["iri_right"],
                 pt["directional_index"], pt["snapstate"],
                )),
              styles=[isty0])
    p0.geometry = Point(pt["lonlat"])
    t.timestamp, dummy = t.parse_str(pt["timestamp"])
    p0.timeStamp = t.timestamp
    f2.append(p0)

  # placemarks with statistics
  for key,pt in snp.snap_aa.items(): # only the unique snap points
    # some headings are reverse, use directional index
    # to orient them correctly
    flip_heading = 0
    if pt["directional_index"] < 0:
      flip_heading = 180;
    iri_avg = (pt["avg_left"] + pt["avg_right"]) / 2
    is0 = styles.IconStyle(ns, "id",
              color=("%08X" % color32(iri_avg/red_iri)),
              scale=1.0,
              heading=(180+pt["heading"]+flip_heading)%360,
              icon_href=arrow_icon_href)
    isty0 = styles.Style(styles = [is0])
    p0 = kml.Placemark(ns, 'id',
              name=("%.2f" % iri_avg),
              description=(("L=%.2f ± %.2f mm/m\n"
                            "R=%.2f ± %.2f mm/m\n"
                            "N=%d\n"
                            "Value ± is 2σ = 96%% coverage\n"
                            "dir_ind=%d\n"
                            "snapstate=%d\n"
                            "%s"
                            ) %
                            (
                             pt["avg_left"], 2*pt["std_left"], pt["avg_right"], 2*pt["std_right"],
                             pt["n"], pt["directional_index"], pt["snapstate"],
                             pt["timestamp"].decode("utf-8"),
                            )
              ),
              styles=[isty0])
    p0.geometry = Point(pt["lonlat"])
    t.timestamp, dummy = t.parse_str(pt["timestamp"])
    p0.timeStamp = t.timestamp
    f2.append(p0)

# output to string with hard-replace "visibility" to add LookAt tag
if True:
  if time_last:
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
  else:
    print(k.to_string(prettyprint=True))
