#!/usr/bin/env python3

# apt install python3-fastkml python3-shapely python3-lxml
# ./wav2kml.py 20210701.wav > 20210701.kml

# TODO gyro calc results differ for iri100, match for iri20
# experimenting with dc_remove_step 1e-4 .. 1e-6 and speed_kmh > 0..2
# values calculated in this code don't match well with hardware calculated for iri100
# TODO accel calc need addtional checking

from fastkml import kml, styles
from shapely.geometry import Point, LineString, Polygon
from sys import argv
from colorsys import hsv_to_rgb
from math import sqrt,sin,cos,asin,pi,ceil,atan2
import numpy as np

wavfile = argv[1]

# calculate
# 0:IRI from wav tags,
# 1:IRI calculated from z-accel wav data (adxl355)
# 2:IRI calculated from x-gyro wav data (adxrs290) angular speed
calculate  = 0
# accel/gyro, select constant and data wav channel
if calculate == 1: # accel adxl355
  g_scale    = 2 # 2/4/8 g is 32000 integer reading
  aint2float = 9.81 * g_scale / 32000 # int -> g conversion factor from accelerometer integer to acceleration float
  # Z-channel of accelerometer
  wav_ch_l = 2
  wav_ch_r = 5
if calculate == 2: # gyro adxrs290
  aint2float = 2*pi/360/200 # gyro angular velocity integer -> rad/s conversion, 1 bit = 1/200 deg/s
  # X-channel of gyroscope
  wav_ch_l = 0
  wav_ch_r = 3

red_iri = 2.5 # colorization

# PPS tag appears as "!" in the data stream, keep it 0 disabled
show_pps = 0

# IRI averaging length (m)
iri_length = 100

# equal-distance slope sampling length (m)
sampling_length = 0.05

# equal-time acclererometer sample time
a_sample_dt = 1/1000 # s (1kHz accelerometer sample rate)    

# slope DC remove by inc/dec of accel offset at each sampling length
dc_remove_step = 1.0e-5

# number of buffered vz speed points for IRI averaging
n_buf_points = int(iri_length/sampling_length + 0.5)
rvz = np.zeros(2).astype(np.uint32)# vz speed contains values scaled as unsigned integer (um/s)
# dimension 2 is for 0=left 1=right index
rvz_buf = np.zeros((n_buf_points,2)).astype(np.uint32)
rvz_buf_ptr = 0 # buffer pointer, runs 0 .. n_buf_points-1, next wraparound to 0
# sum of rectified speeds in um/s, dimension 2 is for 0=left, 1=right
srvz = np.zeros(2).astype(np.uint32)
# slope reconstructed from z-accel and x-speed
slope = np.zeros(2).astype(np.float32)
# for slope DC remove
slope_prev = np.zeros(2).astype(np.float32)

ac = np.zeros(6).astype(np.int16) # current integer accelerations vector

azl0 = 0.0
azr0 = 0.0
if calculate == 1:
  azl0 = 9.81 # average azl (to remove slope DC offset)
  azr0 = 9.81 # average azr (to remove slope DC offset)

# Z state matrix left,right (used for iterative slope entry at each sampling interval)
ZL = np.zeros(4).astype(np.float32)
ZR = np.zeros(4).astype(np.float32)

# ready calculated HSRI-type golden car response coefficients for DX = 0.05 m
ST = np.array([
 [ 9.99847591e-01,  2.23521003e-03,  1.03813734e-04,  1.47621931e-05 ],
 [-1.33122370e-01,  9.87026870e-01,  6.88576102e-02,  1.29245874e-02 ],
 [ 1.01390202e-03,  9.84146318e-05,  9.88310337e-01,  2.14351248e-03 ],
 [ 8.84141088e-01,  8.61639306e-02, -1.02155657e+01,  9.03160334e-01 ]
]).astype(np.float32)
PR = np.array(
 [ 4.85082633e-05,  6.42647498e-02,  1.06757468e-02,  9.33142468e+00 ]
).astype(np.float32)

# calculate HSRI-type golden car response coefficients matrix ST, PR
def st_pr(DX = 0.05, K1 = 653.0, K2 = 62.3, MU = 0.15, C = 6.0):
  global ST, PR
  # DX =   0.05  # m sampling_length (for 0.05 m it takes 2000 points per 100 m)
  # HSRI-type golden car:
  # K1 = 653.0   # tyre stiffness per vehicle body mass
  # K2 =  62.3   # shock absorber spring stiffness per vehicle body mass (wtp-46 uses 63.3)
  # MU =   0.15  # tyre mass per vehicle body mass
  # C  =   6.0   # shock absorber damping coefficient per vehicle body mass
  # BPR-type golden car:
  # K1 = 643.0   # tyre stiffness per vehicle body mass
  # K2 = 128.7   # shock absorber spring stiffness per vehicle body mass
  # MU =   0.162 # tyre mass per vehicle body mass
  # C  =   3.86  # shock absorber damping coefficient per vehicle body mass
  V  = 80/3.6 # m/s standard speed 80 km/h (don't touch)
  T  = DX/V   # seconds time step per sample interval at std speed
  A = np.array(
    [[   0    ,  1    ,       0     ,  0    ],
     [ -K2    , -C    ,      K2     ,  C    ],
     [   0    ,  0    ,       0     ,  1    ],
     [  K2/MU ,  C/MU , -(K1+K2)/MU , -C/MU ]]).astype(np.float32)
  B = np.array(
     [   0    ,  0    ,       0     , K1/MU ]).astype(np.float32)
  # Calculate the state transition matrix 'ST' using a Taylor
  # Series expansion until required precision is reached.
  # ST = e^(A*dt) -> taylor expansion:
  # ST = I + A*dt + A^2*dt^2/2! + A^3*dt^3/3! + ...
  # start from identity matrix, 1 at diagonal, rest 0
  ST = np.identity(4).astype(np.float32)
  An = np.identity(4).astype(np.float32)
  for n in range(1,36): # An should converge to 0 when divided by 35! = 1e40
    An = np.matmul(An, A) * T / n # A^n * dt^n / n!
    ST += An
  # Calculate A matrix inversion A^-1
  Ainv = np.linalg.inv(A)
  #print("Ainv")
  #print(Ainv)
  # Calculate the Partial Response matrix.
  # PR = A^-1 * (ST - I) * B
  PR = np.matmul(np.matmul(Ainv, (ST - np.identity(4))), B)
  #print("ST (State Transition matrix):")
  #print(ST)
  #print("PR (Partial Response matrix):")
  #print(PR)

# enter slope (dimensionless, m vertical per m horizontal) at sampling interval DX
# into a model that simulates vehicle response
# ST 4x4 state transition matrix
# ZL, ZR 4-dim state space vectors
# PR 4-dim partial response vector
def slope2model(slope_l:float, slope_r:float):
  global ZL, ZR
  ZL = np.matmul(ST, ZL) + PR * slope_l
  ZR = np.matmul(ST, ZR) + PR * slope_r
  # return (ZL[0] - ZL[2], ZR[0] - ZR[2]) # shock absorber speed

def slope_dc_remove():
  global azl0, azr0, slope_prev
  if slope[0] > 0 and slope[0] > slope_prev[0]:
    azl0 += dc_remove_step
  if slope[0] < 0 and slope[0] < slope_prev[0]:
    azl0 -= dc_remove_step
  if slope[1] > 0 and slope[1] > slope_prev[1]:
    azr0 += dc_remove_step
  if slope[1] < 0 and slope[1] < slope_prev[1]:
    azr0 -= dc_remove_step
  slope_prev[0] = slope[0]
  slope_prev[1] = slope[1]

# initialization before first data entry
# usually called at stops because slope is difficult to keep after the stop
def reset_iri():
  global ZL, ZR, rvz_buf, rvz_buf_ptr, srvz, slope, slope_prev, azl0, azr0
  # multiply all matrix elements with 0 resets them to 0
  ZL *= 0
  ZR *= 0
  srvz *= 0
  rvz_buf *= 0
  rvz_buf_ptr = 0
  slope *= 0
  slope_prev *= 0
  # reset DC compensation to current accelerometer reading
  azl0 = ac[wav_ch_l]*aint2float
  azr0 = ac[wav_ch_r]*aint2float

# enter slope, calculate running average
def enter_slope(slope_l:float, slope_r:float):
  global rvz, rvz_buf, rvz_buf_ptr, srvz
  slope2model(slope_l, slope_r) # updates ZL, ZR
  # scale shock absorber speed to integer um/s
  rvz[0] = int(abs(1.0e6 * (ZL[0]-ZL[2])))
  rvz[1] = int(abs(1.0e6 * (ZR[0]-ZR[2])))
  # running average
  srvz += rvz - rvz_buf[rvz_buf_ptr] # subtract from sum old data 100 m before
  rvz_buf[rvz_buf_ptr] = rvz # new data
  # next pointer with wraparound
  rvz_buf_ptr += 1
  if rvz_buf_ptr >= n_buf_points:
    rvz_buf_ptr = 0

# slope reconstruction from equal-time sampled z-accel and vehicle x-speed
# updates global slope[0] = left, slope[1] = right
# needs regularly updated azl0, azr0 for slope DC remove
def az2slope(azl:float, azr:float, c:float):
  global slope
  slope[0] += (azl - azl0) * c
  slope[1] += (azr - azr0) * c

# integrate z-acceleration in time domain 
# updates slope in z/x space domain
# needs x-speed as input 
# (vx = vehicle speed at the time when azl,azr accel are measured)
# for small vx model is inaccurate. at vx=0 division by zero
# returns 1 when slope is ready (each sampling_interval), otherwise 0
def enter_accel(azl:float, azr:float, vx:float):
  global travel_sampling
  if calculate == 1:
    c = a_sample_dt / vx
  else: # calculate == 2
    c = a_sample_dt
  az2slope(azl, azr, c)
  travel_sampling += vx * a_sample_dt
  if travel_sampling > sampling_length:
    travel_sampling -= sampling_length
    return 1
  return 0

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
    segment_snap   =  10.0    # [m]
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
    self.snap_list = list()
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

    for gps in gps_list:
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
      for snap_point in self.snap_list:
       if snap_point["directional_index"] > 0:
        #print(snap_point)
        new_distance = distance(snap_point["lonlat"][1], snap_point["lonlat"][0], self.next_gps[gps_lonlat][1], self.next_gps[gps_lonlat][0])
        # find the nearest distance and its list index
        if distance_m == None or new_distance < distance_m:
            distance_m = new_distance
            nearest_index = index
            # current point along the track
            #nearest_point = self.next_gps
            nearest_point = snap_point
        index += 1
      cut_index = index # if we don't find nearest previous point, cut after last point
      if nearest_index != None:
        # print("nearest index ", nearest_index, " distance: ", distance)
        
        # heading of the nearest point
        nearest_heading = self.snap_list[nearest_index]["heading"]

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
              self.cut_at_length = self.prev_gps_track_length + self.current_gps_segment_length - 1.0e3
            #self.cut_at_length = self.prev_gps_track_length + self.current_gps_segment_length - 1.0e3
            #print("snap to ", self.cut_at_length)
        elif snapstate >= 2:
          if distance_m > self.segment_snap:
            snapstate = 0
      else:
        # no nearest index -> snap state = 0
        snapstate = 0
        #cut_index = 0 # do we need this?
 
      # if not found in the snap list:
      # add to the length
      # and when the length is exceeded then interpolate
      # to cut for exactly length [m] segments and add this to
      # snap list
      if snapstate != 1: # if not approaching any snap point
       while self.prev_gps_track_length + self.current_gps_segment_length > self.cut_at_length:
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
        #if nearest_index != None:
        #  segment_index = nearest_index
        #else:
        #  segment_index = index
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
          self.snap_list.append(cut_point)
        # cut point is each point along the track
        self.cut_list.append(cut_point)
        self.cut_at_length += self.segment_length
        # we should leave snap distance before
        # looking for the next snap point
        snapstate = 3
    #print("Snap: %d segment cuts to %d snap points" % (len(self.cut_list), len(self.snap_list)))

  def statistics(self):
    # convert snap list to associative array
    # add fields for statistics, reset to 0
    self.snap_stat = {}
    for pt in self.cut_list:
      key = pt["directional_index"]
      value = pt # copy data from cut_list
      value["n"]          = 0
      value["sum1_left"]  = 0.0
      value["sum2_left"]  = 0.0
      value["avg_left"]   = 0.0
      value["std_left"]   = 0.0
      value["sum1_right"] = 0.0
      value["sum2_right"] = 0.0
      value["avg_right"]  = 0.0
      value["std_right"]  = 0.0
      self.snap_stat[key] = value
    # statistics sums
    for pt in self.cut_list:
      key = pt["directional_index"]
      self.snap_stat[key]["n"]           += 1
      self.snap_stat[key]["sum1_left"]   += pt["iri_left"]
      self.snap_stat[key]["sum2_left"]   += pt["iri_left"]*pt["iri_left"]
      self.snap_stat[key]["sum1_right"]  += pt["iri_right"]
      self.snap_stat[key]["sum2_right"]  += pt["iri_right"]*pt["iri_right"]
    # average and standard dev
    for key,value in self.snap_stat.items():
      n = self.snap_stat[key]["n"]
      if n > 0:
        sum1_left  = self.snap_stat[key]["sum1_left"]
        sum2_left  = self.snap_stat[key]["sum2_left"]
        sum1_right = self.snap_stat[key]["sum1_right"]
        sum2_right = self.snap_stat[key]["sum2_right"]
        self.snap_stat[key]["avg_left"]  = sum1_left/n
        self.snap_stat[key]["avg_right"] = sum1_right/n
        self.snap_stat[key]["std_left"]  = abs( n*sum2_left  - sum1_left  * sum1_left  )**0.5/n
        self.snap_stat[key]["std_right"] = abs( n*sum2_right - sum1_right * sum1_right )**0.5/n

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
d = kml.Document(ns, id='docid', name='DATETIME', description='profilog from wav2kml generator')
#f = kml.Folder(ns, 'fid', 'f name', 'f description')
k.append(d)
#d.append(f)
#nf = kml.Folder(ns, 'nested-fid', 'nested f name', 'nested f description')
#f.append(nf)
recorded_data_description="\
100 m segment cuts with statistics.\n\
Click any point on the track to display mm/m value of a 100 m\n\
segment measured before the point. Value represents average\n\
rectified speed in the shock absorber over 100 m segment\n\
and divided by standard speed of 80 km/h. Value comes from the\n\
numeric model that calculates response at standard speed,\n\
removing dependency on actual speed at which measurement has been done.\n\
\n\
Color codes:\n\
<font color=\"red\">%.1f</font>, <font color=\"orange\">%.1f</font>, <font color=\"green\">%.1f</font>, <font color=\"cyan\">%.1f</font>, \
<font color=\"blue\">%.1f</font>, <font color=\"violet\">%.1f</font>, <font color=\"magenta\">0.0</font>\n\
" % (red_iri, 2.0/2.5*red_iri, 1.5/2.5*red_iri, 1.0/2.5*red_iri,
0.5/2.5*red_iri, 0.3/2.5*red_iri)
f2 = kml.Folder(ns, id='folderid', name='Recorded data', description=recorded_data_description)
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
  iri20_left  = 0.0
  iri20_right = 0.0
  iri20_avg   = 0.0
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
  travel_sampling = 0.0 # m for sampling_interval triggering
  # set nmea line empty before reading
  nmea=bytearray(0)
  while f.readinto(mvb):
    seek += 12 # bytes per sample
    a=(b[0]&1) | ((b[2]&1)<<1) | ((b[4]&1)<<2) | ((b[6]&1)<<3) | ((b[8]&1)<<4) | ((b[10]&1)<<5)
    if calculate:
      for i in range(0,6):
        ac[i] = int.from_bytes(b[i*2:i*2+2],byteorder="little",signed=True)
      if speed_kmh > 2: # TODO unhardcode
        # ac[2] Z-left, ac[5] Z-right
        #print(ac[wav_ch_l]*aint2float, ac[wav_ch_r]*aint2float, azl0, azr0)
        #print(ac[wav_ch_l],ac[wav_ch_r],speed_kmh)
        if enter_accel(ac[wav_ch_l]*aint2float, ac[wav_ch_r]*aint2float, speed_kmh/3.6):
          enter_slope(slope[0],slope[1])
          slope_dc_remove()
          #print(ac[wav_ch_l]*aint2float, ac[wav_ch_r]*aint2float)
          #print(azl0, azr0)
          #print(slope)
          # srvz is scaled 1e6
          # iri when printed should be scaled as 1e3 mm/m so
          # divide srvz by 1000
          #print(srvz)
          #print(srvz / (n_buf_points * 1000))
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
          if calculate:
            reset_iri()
        elif nmea[0:6]==b"$GPRMC" and (len(nmea)==79 or len(nmea)==68) and nmea[-3]==42: # 68 is lost signal, tunnel mode
          # nmea[-3]="*" checks for asterisk on the right place. Not full crc check
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
            if dist_m < discontinuety_m: # don't draw too long lines, colorize iri20
              ls0 = styles.LineStyle(ns,
                color=("%08X" % color32(iri20_avg/red_iri)), width=6)
              lsty0 = styles.Style(styles = [ls0])
              p1 = kml.Placemark(ns, 'id',
                name=("%.2f" % iri_avg),
                description=("L=%.2f mm/m\nR=%.2f mm/m\nL20=%.2f, R20=%.2f\nLc=%.2f, Rc=%.2f\nv=%.1f km/h\n%s" % 
                  (iri_left, iri_right,
                   iri20_left, iri20_right,
                   srvz[0] / (n_buf_points*1000), srvz[1] / (n_buf_points*1000),
                   speed_kmh, datetime.decode("utf-8"))),
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
          spos=nmea.find(b"S")
          epos=nmea.find(b'*')
          if epos < 0:
            epos=nmea.find(b' ')
          try:
            if(rpos > 0):
              iri_left=float(nmea[1:rpos])
              iri_right=float(nmea[rpos+1:epos])
              iri_avg=(iri_left+iri_right)/2
            if(spos > 0):
              iri20_left=float(nmea[1:spos])
              iri20_right=float(nmea[spos+1:epos])
              iri20_avg=(iri20_left+iri20_right)/2
          except:
            pass
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
              description=("L=%.2f mm/m\nR=%.2f mm/m\nL2=%.2f, R2=%.2f\ndir_ind=%d\nsnapstate=%d" %
                (pt["iri_left"], pt["iri_right"],
                 srvz[0] / (n_buf_points*1000), srvz[1] / (n_buf_points*1000),
                 pt["directional_index"], pt["snapstate"],
                )),
              styles=[isty0])
    p0.geometry = Point(pt["lonlat"])
    t.timestamp, dummy = t.parse_str(pt["timestamp"])
    p0.timeStamp = t.timestamp
    f2.append(p0)

  # placemarks with statistics
  for key,pt in snp.snap_stat.items(): # only the unique snap points
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
                             pt["avg_left" ], 2*pt["std_left" ],
                             pt["avg_right"], 2*pt["std_right"],
                             pt["n"],
                             pt["directional_index"],
                             pt["snapstate"],
                             pt["timestamp"].decode("utf-8"),
                            )
              ),
              styles=[isty0])
    p0.geometry = Point(pt["lonlat"])
    t.timestamp, dummy = t.parse_str(pt["timestamp"])
    p0.timeStamp = t.timestamp
    f2.append(p0)

# output to string with hard-replace "description" to add LookAt tag
if True:
  if time_last:
    print(k.to_string(prettyprint=True).replace(
  "</Document>",
  "  <LookAt>\n\
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
    </LookAt>\n\
  </Document>" % (lonlat_1st[0], lonlat_1st[1], time_1st.decode("utf-8"), time_last.decode("utf-8"))
    ))
  else:
    print(k.to_string(prettyprint=True))

#st_pr(DX=sampling_length)
#print(ST)
#print(PR)
#print(n_buf_points)
#reset_iri()
#enter_slope(2.0e-3,2.0e-3)
#print(rvz_buf, srvz)
#enter_slope(0.0e-3,0.0e-3)
#print(rvz_buf, srvz)
#az2slope(1+0.01,1-0.01,22.2222)
#print(slope)
#az2slope(1-0.01,1+0.01,22.2222)
#print(slope)
