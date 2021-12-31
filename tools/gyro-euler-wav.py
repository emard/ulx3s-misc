#!/usr/bin/env python3

# ./gyro-euler-wav.py file.wav

# coordinates relative to sensor
# sensor0 (left)  in XY plane (pins pointing to sensor's Y direction, pcb horizontal parts up)
# sensor1 (right) in XZ plane (rotated 90 deg clockwise around pins axis, pcb vertical, parts to the right)

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
from math import sin,cos,tan,pi
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

# calculate factors to let fixed point math work with sufficient precision
# and result to binary angular scale
# 2**iscale is equivalent of 2*pi rad or 360 deg
# scale 2**41 fits 16-bit signed sine table 0 .. +30542 .. -30542
# scale 2**35 fits 10-bit signed sine table 0 .. +477   ..   -477 (optimal for 9-bit BRAM)
# scale 2**32 fits  7-bit signed sine table 0 ..  +60   ..    -60 (still ok precision)
iscale = 35
valisc = 1<<iscale
andisc = (1<<iscale)-1
# p scale factor with T, makes (p) 2**iscale binary angle
ugp = int((1<<iscale) * T / 360 / 200 + 0.5) # 477
# tsin scale factor with T, makes (q, r) 2**iscale binary angle
ugs = int((1<<iscale) * T / 360 / 200 + 0.5) # 477
# ttan, tsec scale factor without T
itscale = 10
ugt = 1<<itscale

# initial euler angles
phi   = 0.0
theta = 0.0
psi   = 0.0

# initial euler angles (fixed point integer 2**iscale factor)
sphi   = 0
stheta = 0
spsi   = 0

# 1: float, 0:integer
mode_float = 0

# integer mode: 0: approx tan(x)=x, 1: use tan table
mode_tan_table = 1

# range 0-pi/2 = 0-2047 trig tables
# int address trig scale
iascale = 13
ntp = int(1<<iascale)
andntp = ntp-1
tsin = np.zeros(ntp).astype(np.int16)
ttan = np.zeros(ntp).astype(np.int16)
tsec = np.zeros(ntp).astype(np.int16) # sec(x) = 1/cos(x)
for i in range(ntp):
  a = i*(2*pi)/ntp
  tsin[i] = ugs*sin(a)
  # avoid int overflow at +-pi/2, i == ntp//4 or i == ntp*3//4
  if (i - ntp//4) & (ntp//2-1):
    try:
      ttan[i] = ugt*tan(a)
    except:
      print("ttan[%d] overflow", i)
    try:
      tsec[i] = ugt/cos(a)
    except:
      print("tsec[%d] overflow", i)
print(tsin[ntp//4//3-1],ttan[ntp//4//3-1],tsec[ntp//4//3-1])

# integer offsets used in closed loop for phi = theta = 0 convergence
iop = 0
ioq = 0
ior = 0

# closed loop control counter
clc_count = 0
# frequency of control actions
clc_every = 129
# angles from previous control cycle
prev_phi   = 0.0
prev_theta = 0.0
prev_psi   = 0.0

# angles from previous control cycle, integer mode
prev_sphi   = 0
prev_stheta = 0
prev_spsi   = 0

for wavfile in argv[1:]:
  f = open(wavfile, "rb")
  f.seek(44) # skip wav header, go to data
  n = 0
  while f.readinto(mvb):
    for j in range(0,6):
      ac[j] = int.from_bytes(b[j*2:j*2+2],byteorder="little",signed=True)
    # integer (ip, iq, ir) values remove LSB and fix static offsets
    ip = (ac[1]&-2) + iop # sensor0 Y = euler X - direction parallel to pins
    iq = (ac[0]&-2) + ioq # sensor0 X = euler Y - direction 90 deg to pins, still in the horizontal plane
    ir = (ac[3]&-2) + ior # sensor1 X = euler Z - (Y of sensor rotated 90 deg around pins axis, vertical plane)
    # orient and scale integers to (p, q, r) rad/s angular rates around axis
    p =  gs * ip
    q =  gs * iq
    r =  gs * ir
    # discrete-time integral to euler angles
    phi   += T * ( p + q * sin(phi) * tan(theta) + r * cos(phi) * tan(theta) )
    theta += T * (     q * cos(phi)              - r * sin(phi)              )
    psi   += T * (     q * sin(phi) / cos(theta) + r * cos(phi) / cos(theta) )

    # binary scaled integer angles 2*pi rad = 360 deg = 1<<iscale
    # addresses for trig tables:
    asphi    = (sphi   >> (iscale-iascale)) & andntp
    acphi    = (asphi  +  ntp//4          ) & andntp # phi + 90 deg for cos
    atheta   = (stheta >> (iscale-iascale)) & andntp

    # discrete-time integral to euler angles
    #sphi    += ip * ugp + ( iq * tsin[asphi] + ir * tsin[acphi] ) * ttan[atheta] // ugt
    #stheta  +=              iq * tsin[acphi] - ir * tsin[asphi]
    #spsi    +=            ( iq * tsin[asphi] + ir * tsin[acphi] ) * tsec[atheta] // ugt

    isinphi  = tsin[asphi]
    icosphi  = tsin[acphi]

    iqpr     = iq * isinphi + ir * icosphi
    iqnr     = iq * icosphi - ir * isinphi

    if mode_tan_table:
      # using tan,sec tables
      # good for theta < 75 deg
      sphi    += ip * ugp + iqpr * ttan[atheta] // ugt
      stheta  +=            iqnr
      spsi    +=            iqpr * tsec[atheta] // ugt
    else:
      # simplification without tan,sec tables
      # good for theta < 15 deg
      # approx tan(theta)=theta, sec(theta)=1, cos(phi)=1
      # satheta is atheta with correct sign
      if stheta < valisc//2:
        itheta =  stheta>>(iscale-itscale)
      else:
        itheta = (stheta>>(iscale-itscale))-ugt
      sphi    += ip * ugp + iqpr * itheta // ugt
      stheta  +=            iqnr
      spsi    +=            iqpr

    # wraparound 360 deg using binary "and"
    sphi    &= andisc
    stheta  &= andisc
    spsi    &= andisc

    # print angles scaled to deg
    if n % 100 == 0:
      print("  𝜙 [°]  𝜃 [°]  𝛹 [°]     p      q      r  %5d" % n)
      #      123456712345671234567123456712345671234567
    n += 1
    print("%+7.1f%+7.1f%+7.1f%+7d%+7d%+7d" % 
         ( phi*180/pi, theta*180/pi, psi*180/pi, ip, iq, ir) )
    print("%7d%7d%7d %10X %10X %10X" % 
         ( (sphi>>(iscale-10))*360>>10, (stheta>>(iscale-10))*360>>10, (spsi>>(iscale-10))*360>>10, sphi, stheta, spsi) )
    # remove drift:
    # closed loop control for phi = theta = psi = 0
    if mode_float:
      # adjust based on floating point angles
      if clc_count >= clc_every:
        # if angle is positive and increasing, decrease offset
        if phi   > 0 and phi   - prev_phi   > 0:
          iop -= 1
        if theta > 0 and theta - prev_theta > 0:
          ioq -= 1
        if psi   > 0 and psi   - prev_psi   > 0:
          ior -= 1
        # if angle is negative and decreasing, increase offset
        if phi   < 0 and phi   - prev_phi   < 0:
          iop += 1
        if theta < 0 and theta - prev_theta < 0:
          ioq += 1
        if psi   < 0 and psi   - prev_psi   < 0:
          ior += 1
        # store current values as previous for next control cycle
        prev_phi   = phi
        prev_theta = theta
        prev_psi   = psi
        clc_count  = 0
      else:
        clc_count += 1
    else:
      # adjust based on integer angles (unsigned int)
      if clc_count >= clc_every:
        # if angle is positive and increasing, decrease offset
        if sphi   < valisc//2 and ((sphi   - prev_sphi  ) & andisc) < valisc//2:
          iop -= 1
        if stheta < valisc//2 and ((stheta - prev_stheta) & andisc) < valisc//2:
          ioq -= 1
        if spsi   < valisc//2 and ((spsi   - prev_spsi  ) & andisc) < valisc//2:
          ior -= 1
        # if angle is negative and decreasing, increase offset
        if sphi   > valisc//2 and ((sphi   - prev_sphi  ) & andisc) > valisc//2:
          iop += 1
        if stheta > valisc//2 and ((stheta - prev_stheta) & andisc) > valisc//2:
          ioq += 1
        if spsi   > valisc//2 and ((spsi   - prev_spsi  ) & andisc) > valisc//2:
          ior += 1
        # store current values as previous for next control cycle
        prev_sphi   = sphi
        prev_stheta = stheta
        prev_spsi   = spsi
        clc_count  = 0
      else:
        clc_count += 1
