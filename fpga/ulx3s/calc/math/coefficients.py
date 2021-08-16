#!/usr/bin/env python3

# This program calculates the coefficients needed to simulate
# the reference vehicle that is the basis of the IRI from WTP-46

import numpy as np

# Set sample interval and convert to time step at 80 km/h

def st_pr(M = 0.25, K1 = 653.0, K2 = 63.3, MU = 0.15, C = 6.0):

  # M = 0.25 # m sample interval (for 0.25 m it takes 400 points per 100 m)

  V  = 80  # km/h standard speed (don't touch)
  T  = M * 3.6 / V # seconds time step per sample interval

  # print("dx =", M, "m, dt =", T, "sec")

  # Initialize vehicle constatns (spring rates, masses, damper)

  #K1 = 653.0
  #K2 =  63.3
  #MU =   0.15
  #C  =   6.0

  N  =   4 # matrix dimension

  A = np.array(
    [[     0,    1,           0,     0],
     [   -K2,   -C,          K2,     C],
     [     0,    0,           0,     1],
     [ K2/MU, C/MU, -(K1+K2)/MU, -C/MU]]).astype(np.float32)

  B = np.array(
    [ 0, 0, 0, K1/MU ]).astype(np.float32)

  #print("A")
  #print(A)
  #print("B")
  #print(B)

  # Calculate the state transition matrix 'ST' using a Taylor
  # Series expansion until required precision is reached.
  # ST = e^(A*dt) -> taylor expansion:
  # ST = I + A*dt + A^2*dt^2/2! + A^3*dt^3/3! + ...
  ST = np.identity(N).astype(np.float32) # starts from identity matrix
  An = A * T # A^n * dt^n / n! (initialized for first loop iteration = A*dt)
  n = 1 # loop counter used for factorial (2! after the first loop iteration)
  while An.any(): # while any element != 0
    ST += An
    n += 1
    An = np.matmul(An, A) * T / n # A^n * dt^n / n! for next iteration

  # Calculate A matrix inversion A^-1
  Ainv = np.linalg.inv(A)

  # Calculate the Partial Response matrix.
  # PR = A^-1 * (ST - I) * B
  PR = np.matmul(np.matmul(Ainv, (ST - np.identity(N))), B)

  #print("ST (State Transition matrix):")
  #print(ST)

  #print("PR (Partial Response matrix):")
  #print(PR)

  return (ST,PR)
