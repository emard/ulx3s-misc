#!/usr/bin/env python3

import math, numpy, struct
from sympy import *

# set some vars that take part in following symbolc function and differentiation
x,y,z = symbols("x y z", real=True)

# profile x [m] -> z [m]
def fpath_sympy(x):
  # this makes profile with IRI=1 m/km
  return \
    +2.1e-3*cos(2*pi*0.09*x+0.02/0.0111111*cos(2*pi*0.0111111*x))

# example: this makes profile with IRI=1 m/km
#    +2.1e-3*cos(2*pi*0.09*x+0.02/0.0111111*cos(2*pi*0.0111111*x))
#    +5.0e-6*cos(2*pi*4.50*x+0.10/0.0526315*cos(2*pi*0.0526315*x))  # should not affect IRI much

d1fpath_sympy = diff(  fpath_sympy(x),x) # 1st derivative
d2fpath_sympy = diff(d1fpath_sympy   ,x) # 2nd derivative

# lambdify: convert symbolic function to global function suitable for numerical evaluation
fpath   = lambdify(x,   fpath_sympy(x))
# 1st derivative, done symbolic and converted similar as above
d1fpath = lambdify(x, d1fpath_sympy)
# 2nd derivative, done symbolic and converted similar as above
d2fpath = lambdify(x, d2fpath_sympy)
# global function that calculates angle of the line perpendicular to fpath:
def phi_fpath(x):
  return math.atan(d1fpath(x))+numpy.pi/2
# accelerometer reading in time domain (FIXME is this correct)
# x = t * vx
# x += vx * dt # integrate x with vx
# vz =  dz/dt =  dz/dx(x)  * dx/dt      = d1fpath(x) * vx
# az = dvz/dt = d2z/d2x(x) * (dx/dt)**2 = d2fpath(x) * vx**2

class accel_sim:
  "accelerometer response simulator"
  def __init__(self,dt,vx):
    self.dt = dt
    self.vx = vx
    self.x  = 0.0

  def z(self):
    "each invocation returns accelerometer z-axis reading after next dt time"
    self.x += self.dt * self.vx
    return 9.81 + d2fpath(self.x) * self.vx * self.vx # FIXME wav2kml calculates iri=1.2-1.5 not ok
    #return d2fpath(self.x) * self.vx * self.vx # wav2kml calculates iri=1.05-1.10 maybe ok

def checksum(x):
  s = 0
  for b in x:
    s ^= ord(b)
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
dt = 1.0e-3 # [s] sampling interval
vx = 80/3.6 # [m/s] vehicle speed [km/h] -> [m/s]
accel = accel_sim(dt, vx) # accelerometer z-axis simulator
g_scale = 4 # accelerometer digital scale setting 2/4/8 g full scale 32000
iscale = 32000/g_scale/9.81 # factor conversion from [m/s**2] to sensor binary reading
rp = 500.0 # [m] path radius
w = vx / rp # [rad/s] angular speed
nturns = 3 # use 3 to shoreten calc time
nsamples = int(nturns*2*rp*math.pi/vx/dt) # mum of samples for N turns
tag = "" # tag queue string starts as empty
for i in range(nsamples):
  iaz = int(iscale*accel.z())
  sample = bytearray(struct.pack("<hhhhhh", 
    int(1000*math.sin(i/20)), int(1000*math.sin(i/30)), iaz,
    int(1000*math.sin(i/20)), int(1000*math.sin(i/30)), iaz
  ))
  if i % 200 == 0: # every 200 samples = 0,2 seconds
    angle10 = int(i*w*dt*1800.0/math.pi) # [deg*10]
    angle = angle10//10 # [deg]
    angle_bidirectional = abs(angle-360*5) # [deg]
    angle_imperfection = angle_bidirectional # % 360
    lr = rp + rp/100*math.sin(angle/10) # [m] + 1% imperfection (radius)
    lx = lr * math.sin(angle_imperfection*math.pi/180)
    ly = lr * math.cos(angle_imperfection*math.pi/180)
    lonumin = int(30000000 + 768 * lx) # EW direction
    latumin = int(30000000 + 540 * ly) # NS direction
    flip = 0
    if angle < 360*5:
      flip = 180
    heading = (angle_bidirectional+90+flip) % 360
    gps_data = "GPRMC,%02d%02d%02d.%1d,A,%02d%02d.%06d,N,%03d%02d.%06d,E,%06.2f,%05.1f,%02d%02d%02d,000.0,E,N" % (
      angle//3600,angle//60%60,angle%60,angle10%10, # hms.1/10
      45,latumin//1000000,latumin%1000000,  # lat
      16,lonumin//1000000,lonumin%1000000,  # lon
      vx*1.944, # kt (43.2 kt = 80 km/h)
      heading,
      1,1,1  # dmy
    )
    tag += " $%s*%02X " % (gps_data, checksum(gps_data))
    # alternate iri 100/20
    if (i // 200) & 1:
      iri_data = ("L%05.2fR%05.2f" % (1.0, 1.0)) # iri100
    else:
      iri_data = ("L%05.2fS%05.2f" % (1.0, 1.0)) # iri20 has "S" instead of "R"
    tag += " %s*%02X " % (iri_data, checksum(iri_data[1:]))
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
