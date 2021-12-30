#!/usr/bin/env python3

# ./gyro-euler-wav.py file.wav

# coordinates relative to sensor
# sensor0 (left)  in XY plane (pins pointing to sensor's Y direction)
# sensor1 (right) in XZ plane (rotated 90 deg around pins direction)

# Euler coordinates
# euler X = sensor0 Y
# euler Y = sensor0 X
# euler Z = sensor1 X

# Euler angles
# 𝜙 (phi)   [rad] rotation around X-axis (direction of travel)
# 𝜃 (theta) [rad] rotation around Y-axis (direction 90 deg to the right of travel)
# 𝛹 (psi)   [rad] rotation around Z-axis (direction downwards)

# from gyro body rates p(x),q(y),r(z) integrate inertial (euler) angles phi(x), theta(y)
# this math is valid only if theta and phi do not approach pi/2 rad (90 deg) (division by zero)
# this math should work in case of romobile vehicle

# [ d𝜙/dt ] = [ p + q sin(𝜙) tan(𝜃) + r cos(𝜙) tan(𝜃) ]
# [ d𝜃/dt ] = [     q cos(𝜙)        - r sin(𝜙)        ]
# [ d𝛹/dt ] = [     q sin(𝜙)/cos(𝜃) + r cos(𝜙)/cos(𝜃) ]

# discrete-time integration:

# 𝜙 += T ( p + q sin(𝜙) tan(𝜃) + r cos(𝜙) tan(𝜃) )
# 𝜃 += T (     q cos(𝜙)        - r sin(𝜙)        )
# 𝛹 += T (     q sin(𝜙)/cos(𝜃) + r cos(𝜙)/cos(𝜃) )

# [ dphi   / dt ] = [ p + q * sin(phi) * tan(theta) + r * cos(phi) * tan(theta) ]
# [ dtheta / dt ] = [     q * cos(phi)              - r * sin(phi)              ]
# [ dpsi   / dt ] = [     q * sin(phi) / cos(theta) + r * cos(phi) / cos(theta) ]
# for (p,q,r) sampled at constant time intervals (T = 1 ms = 1E-3 s):
# phi   += T * ( p + q * sin(phi) * tan(theta) + r * cos(phi) * tan(theta) )
# theta += T * (     q * cos(phi)              - r * sin(phi)              )
# psi   += T * (     q * sin(phi) / cos(theta) + r * cos(phi) / cos(theta) )


from sys import argv
from math import sqrt,sin,cos,tan,asin,pi,ceil,atan2
import numpy as np

# buffer to read wav
b=bytearray(12)
mvb=memoryview(b)

# array to store int gyro values
ac = np.zeros(6).astype(np.int16) # current integer gyro vector

# sampling time
T = 1.0E-3

# int to rad/s gyro scale
gs = (pi/180)/200

# initial euler angles
phi   = 0.0
theta = 0.0
psi   = 0.0

ap = 0
aq = 0
ar = 0

for wavfile in argv[1:]:
  f = open(wavfile, "rb")
  f.seek(44) # skip wav header, go to data
  n = 0
  while f.readinto(mvb):
    for j in range(0,6):
      ac[j] = int.from_bytes(b[j*2:j*2+2],byteorder="little",signed=True)
    # integer (ip, iq, ir) values remove LSB and fix static offsets
    ip = (ac[1]&-2) - 24 # sensor0 Y = euler X - direction parallel to pins
    iq = (ac[0]&-2) + 32 # sensor0 X = euler Y - direction 90 deg to pins, still in the horizontal plane
    ir = (ac[3]&-2) - 28 # sensor1 X = euler Z - (Y of sensor rotated 90 deg around pins axis, vertical plane)
    # orient and scale integers to (p, q, r) rad/s angular rates around axis
    p =  gs * ip
    q =  gs * iq
    r =  gs * ir
    # discrete-time integral to euler angles
    phi   += T * ( p + q * sin(phi) * tan(theta) + r * cos(phi) * tan(theta) )
    theta += T * (     q * cos(phi)              - r * sin(phi)              )
    psi   += T * (     q * sin(phi) / cos(theta) + r * cos(phi) / cos(theta) )
    # print angles scaled to deg
    if n % 100 == 0:
      print("      𝜙      𝜃      𝛹      p      q      r  %5d" % n)
      #      123456712345671234567123456712345671234567
    n += 1
    print("%+7.1f%+7.1f%+7.1f%+7d%+7d%+7d" % 
         ( phi*180/pi, theta*180/pi, psi*180/pi, ip, iq, ir) )
    # debug
    #ap += ip
    #aq += iq
    #ar += ir
    #print("%+7d%+7d%+7d" % (ap, aq, ar))
