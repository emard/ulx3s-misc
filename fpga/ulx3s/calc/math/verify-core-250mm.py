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
points = 201
dx = 0.25
x = np.zeros(points).astype(np.float32)
for i in range(0,points):
  x[i] = i * dx
z = np.zeros(points).astype(np.float32)
# triangle bump
for i in range(0,9):
  z[4+i] = i * dx
  z[20-i] = i * dx
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
#for i in range(1,points):
print("Z")
print(roughness.Z);
print("Z1")
print(roughness.Z);
print("")
for i in range(1,points):
  yp = 0x400
  #yp = -0x1000
  roughness.enter_slope(yp)
  iri[i] = roughness.IRI() 
  # x10 to fit on the same plot,
  # on wtp-46 plot left side is displacement with scale: 0-8
  # on wtp-46 plot right side is iri with scale 0-0.8
  print("%3d %6.2f YP=0x%08X IRI=%9.5f VZ=0x%08X" % (i,x[i],yp,iri[i], roughness.Z[0]-roughness.Z[2] + 0x100000000 & 0xFFFFFFFF ))
  print("Z=[ 0x%08X 0x%08X 0x%08X 0x%08X ]" % (roughness.Z[0] + 0x100000000 & 0xFFFFFFFF, roughness.Z[1] + 0x100000000 & 0xFFFFFFFF, roughness.Z[2] + 0x100000000 & 0xFFFFFFFF,roughness.Z[3] + 0x100000000 & 0xFFFFFFFF))
  print(roughness.Z);
  print("")
  #print(i,"z",z[i],"iri",iri[i])
  