#!/usr/bin/env python3

# verification:
# generating profile from WTP-46
# and getting identical results

# calculates z-acceleration over the profile
# calculates slope from z-acceleration and
# verifies that IRI can be calculated from
# the slope with very high precision.

from matplotlib.pylab import *  # pylab is the easiest approach to any plotting
import numpy as np

# import local vehicle response analyzer package
import goldencar

# ----------- generate test profile "triangular bump" from wtp-46 p.41
traclen = 50
dx = 0.25
n0 = int(traclen/dx+0.5)
points = n0 + 1
x = np.zeros(points).astype(np.float32)
for i in range(0,points):
  x[i] = i * dx
z = np.zeros(points).astype(np.float32)
# triangle bump
n1 = int(2.5/dx+0.5)
for i in range(0,n1-1):
  z[n1//2-1+i] = i * dx
  z[2*n1-i] = i * dx
# linear slope - IRI not sensitive to constant slope
#for i in range(0,points-10):
#  z[10+i] = i * dx / 10
# acceelerated slope - IRI not sensitive to constant acceleration
#for i in range(0,points-10):
#  z[10+i] = (i * dx)**2 / 100
# add triangle bump - IRI sensitive to this
#for i in range(0,9):
#  z[4+i] += i * dx
#  if i < 8:
#    z[20-i] += i * dx

iri = np.zeros(points).astype(np.float32)

# ----------- instantiate goldencar model
roughness = goldencar.response(sampling_interval = dx, iri_length = 100.0, buf_size = points)

# ---- enter profile to goldencar model and print results
for i in range(1,points):
  roughness.enter(z[i])
  iri[i] = 10*roughness.IRI() 
  # x10 to fit on the same plot,
  # on wtp-46 plot left side is displacement with scale: 0-8
  # on wtp-46 plot right side is iri with scale 0-0.8
  #print("%6.2f %6.2f %9.5f" % (x[i],z[i],iri[i]))

# variable x-speed over the x range in m/s
vx = np.zeros(points).astype(np.float32)
start_speed = 20
for i in range(0,points//2+1):
  vx[i] = start_speed+0.1*i
  vx[points-1-i] = start_speed+0.1*i

# z-speed differentially calculated
vz = np.zeros(points).astype(np.float32)
for i in range(1,points-1):
  vz[i] = (z[i]-z[i-1])*vx[i]/dx

# z-acceleration differentially calculated
az = np.zeros(points).astype(np.float32)
for i in range(1,points-1):
  az[i] = (vz[i]-vz[i-1])*vx[i]/dx

# z-slope integrated from acceleration
# over dx. Hardware will integrate
# over dt (sample interval 1kHz).
# dt=dx/vx then s += az[i]/vx[i]*dt
sz = np.zeros(points).astype(np.float32)
s = 0.0
for i in range(0,points):
  s += az[i]/(vx[i]*vx[i])*dx
  sz[i] = s

# -------- calculate IRI from the slope
iri2 = np.zeros(points).astype(np.float32)
roughness.reset()

# ---- enter profile to goldencar model and print results
for i in range(1,points):
  roughness.enter_slope(int(sz[i]*roughness.scale_int_z))
  iri2[i] = 10*roughness.IRI() 
  # x10 to fit on the same plot,
  # on wtp-46 plot left side is displacement with scale: 0-8
  # on wtp-46 plot right side is iri with scale 0-0.8
  #print("%6.2f %6.2f %9.5f" % (x[i],z[i],iri2[i]))

# show it graphically
plot(
  x,    z, "",
  x,  iri, "",
  x,   sz, "",
  x, iri2, ""
)
grid()
show()
