#!/usr/bin/env python3

# This program calculates the coefficients needed to simulate
# the reference vehicle that is the basis of the IRI from WTP-46

import numpy as np

# Set sample interval and convert to time step at 80 km/h

MM = 250 # mm sample interval (normal 400 points per 100 m)
#MM = 195.3125 # mm sample interval (experimental 512 points per 100 m)
V  = 80  # km/h
T  = MM / V * 0.0036 # seconds time step per sample interval

# Initialize vehicle constatns (spring rates, masses, damper)

N  =   4
K1 = 653.0
K2 =  63.3
MU =   0.15
C  =   6.0

A = np.array(
  [[     0,    1,           0,     0],
   [   -K2,   -C,          K2,     C],
   [     0,    0,           0,     1],
   [ K2/MU, C/MU, -(K1+K2)/MU, -C/MU]]).astype(np.float32)
A1 = np.identity(N).astype(np.float32)
A2 = np.zeros((N,N)).astype(np.float32)
ST = np.identity(N).astype(np.float32)
PR = np.zeros((N)).astype(np.float32)

print("dx =", MM, "mm, dt =", T, "sec")

# Build the 'A' matrix from the vehicle parameters and
# initialize the 'ST' matrix

print("Initialized A")
print(A)

# Calculate the state transition matrix 'ST' using a Taylor
# Series expansion.  The variable 'IT' counts iterations in
# the series.  The variable 'IS' is used to indicate when the
# series has converged.  (IS=0 means that no changes in 'ST'
# occured in the current iteration.)

IT = 0
IS = 1
while IS:
  IT = IT + 1
  IS = 0
  for J in range(N):
    for I in range(N):
      A2[I,J] = 0.0
      for K in range(N):
        A2[I,J] = A2[I,J] + A1[I,K] * A[K,J]
  for J in range(N):
    for I in range(N):
      A1[I,J] = A2[I,J] * T / IT
      if ST[I,J] != ST[I,J] + A1[I,J]:
        ST[I,J] = ST[I,J] + A1[I,J]
        IS = 1

# Calculate A matrix inversion

A = np.linalg.inv(A)

print("Inverted A")
print(A)

# Calculate the Partial Response matrix.

for I in range(N):
  PR[I] = -A[I,N-1]
  for J in range(N):
    PR[I] = PR[I] + A[I,J] * ST[J,N-1]
  PR[I] = PR[I] * K1 / MU
# next I

print("ST (State Transition matrix):")
print(ST)

print("PR (Partial Response matrix):")
print(PR)
