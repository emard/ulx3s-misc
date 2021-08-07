#!/usr/bin/env python3

# discrete time domaun "golden" car response

# from numpy import *

import numpy as np

# circular sample buffer for
# full segment: 100 m (IRI100)
# sub segment: 20 m (IRI20)

# allocate circular buffer for 10000 samples with circular pointer
# allocate separate set of bins for spectrum and subspectrum

# try to scale each sample entry to max 15-bit -16383..+16383
# in real situation they should not overflow any bin
# track and report bin overflows

# spectrum.enter(z)
# enter z-elevation for next x-sampling interval
# calculate moving average (remove oldest entry from the buffers)
# entry is in form of spatial z-value in meters, height

# IRI: calculate floating point IRI mm/m for full segment
# subIRI: calculate IRI for subsegment

# reset: delete all points, set history all to 0 (flat surface)

class response:
  "Frequency response function for IRI calculation"
  def __init__(self, sampling_interval=0.25, iri_length=100, buf_size=2048):
    self.full_seg_size = int(iri_length / sampling_interval + 0.5) 
    # TODO calculate buf size to fit full_seg_size
    self.buf_size = buf_size
    self.ptr = 0
    standard_speed_kmh = 80.0 # km/h
    self.standard_speed = standard_speed_kmh/3.6 # m/s
    self.scale_int_x =   int(1.0e3) # x in millimeters, don't touch
    self.scale_int_z =   int(1.0e6) # z in micrometers, fixed point scale
    self.scale_int_matrix = 20      # 2**n scale matrix elements to integers
    # allocate numpy array to the size
    #self.buf_x = np.zeros(self.buf_size).astype(np.int32) # mm
    #self.buf_z = np.zeros(self.buf_size).astype(np.int32) # um
    self.buf_rvz = np.zeros(self.buf_size).astype(np.int32) # um/s rectified velocity
    self.Y = np.zeros(2).astype(np.int32)
    self.Z = np.zeros(4).astype(np.int32)
    self.Z1 = np.zeros(4).astype(np.int32)
    self.set_sampling_interval(sampling_interval)
    self.reset()

  # argument is integer, scaled x-value (mm) sampling interval
  def set_sampling_interval(self, interval_m = 0.25):
    self.interval_m = interval_m
    self.interval_mm = int(self.interval_m * self.scale_int_x + 0.5)
    # coefficients taken from p.36 of WTP-46
    # http://documentos.bancomundial.org/curated/es/851131468160775725/pdf/multi-page.pdf
    if self.interval_mm == 50:
      self.ST = np.array([
        [  0.9998452  ,  2.235208e-3,  1.062545e-4,  1.476399e-5  ],
        [ -0.1352583  ,  0.9870245  ,  7.098568e-2,  1.292695e-2  ],
        [  1.030173e-3,  9.842664e-5,  0.9882941  ,  2.143501e-3  ],
        [  0.8983268  ,  8.617964e-2,-10.2297     ,  0.9031446    ]
      ])
      self.PR = np.array([
           4.858894e-5,
           6.427258e-2,
           1.067582e-2,
           9.331372
      ])
    if self.interval_mm == 250:
      self.ST = np.array([
        [  0.9966071  ,  1.091514e-2, -2.083274e-3,  3.190145e-4  ],
        [ -0.5563044  ,  0.9438768  , -0.8324718  ,  5.064701e-2  ],
        [  2.153176e-2,  2.126763e-3,  0.7508714  ,  8.221888e-3  ],
        [  3.335013   ,  0.3376467  ,-39.12762    ,  0.4347564    ]
      ])
      self.PR = np.array([
           5.476107e-3,
           1.388776   ,
           0.2275968  ,
          35.79262
      ])
    # conversion to int with scale foctor
    self.int_ST = (self.ST * (1<<self.scale_int_matrix)).astype(np.int32)
    self.int_PR = (self.PR * (1<<self.scale_int_matrix)).astype(np.int32)
    #print(self.int_ST)
    #print(self.int_PR)

  # integer multiply for int-scale matrix element
  # a: int matrix element, int-scaled 1<<20 = about 1e6
  # b: int unscaled element
  def imul(self, a:np.int32, b:np.int32) -> np.int32:
    xa=np.zeros(1).astype(np.int64) # for 64-bit mul to avoid overflow
    xa[0]=a
    return (xa[0]*b)>>self.scale_int_matrix

  def reset(self, z = 0.0):
    int_z = int(z * self.scale_int_z + 0.5)
    # reset buffers
    #self.buf_x *= 0
    #self.buf_z *= 0
    self.buf_rvz *= 0
    self.Y *= 0
    self.Z *= 0
    self.Z1 *= 0
    # set initial state vars
    self.DX = self.interval_m
    self.Y[0] = int_z
    self.Y[1] = int_z
    self.Z1[0] = int((self.Y[1] - self.Y[0]) / self.DX + 0.5 )
    self.Z1[1] = 0
    self.Z1[2] = self.Z1[0]
    self.Z1[3] = 0
    self.RS = 0
    self.I = 0
    self.X = 0 # mm counted with I

  # calculate slope for subsequent z elevation entries
  # each new elevation is measured at next self.DX distance
  # input z (um) micrometers
  # output slope (um/m) micrometers per meter
  def slope_from_z(self, z) -> int:
    self.Y[1] = z
    # -------------------------------------------------------- Calculate slope
    int_yp = int((self.Y[1] - self.Y[0]) / self.DX + 0.5)
    self.Y[0] = self.Y[1]
    return int_yp

  # calculate vehicle response for subsequent slope entries
  # each new slope is measured at next self.DX distance
  # input slope yp (um/m) micrometers per meter
  # output vz (um/s) micrometers per second
  def vz_from_slope(self, int_yp:int) -> int:
    # ---------------------------------------------- Simulate vehicle response
    for j in range(0,4):
      #self.Z[j] = int(self.PR[j] * int_yp + 0.5)
      self.Z[j] = self.imul(self.int_PR[j], int_yp)
      for jj in range(0,4):
        #self.Z[j] += int(self.ST[j,jj] * self.Z1[jj] + 0.5)
        self.Z[j] += self.imul(self.int_ST[j,jj], self.Z1[jj])
    for j in range(0,4):
      self.Z1[j] = self.Z[j]
    return self.Z[0] - self.Z[2]

  # each new elevation is measured at next self.DX distance
  def enter(self, z):
    int_z = int(z * self.scale_int_z + 0.5)
    if self.I >= self.full_seg_size:
      self.I = self.full_seg_size
      # calculate position to remove from history
      prev_ptr = (self.ptr + self.buf_size - self.full_seg_size) % self.buf_size
      #prev_x = self.buf_x[prev_ptr]
      #prev_z = self.buf_z[prev_ptr]
      prev_rvz = self.buf_rvz[prev_ptr]
      self.RS -= prev_rvz
    else:
      self.I += 1
    self.X += self.interval_mm
    # calculate slope
    int_yp = self.slope_from_z(int_z)
    # calculate new rvz (RS increment)
    int_rvz = abs(self.vz_from_slope(int_yp))
    self.RS += int_rvz
    #self.buf_x[self.ptr] = self.X
    #int_z = int(z * self.scale_int_z)
    #self.buf_z[self.ptr] = int_z
    self.buf_rvz[self.ptr] = int_rvz
    self.ptr = (self.ptr + 1) % self.buf_size

  # calculate vehicle response for subsequent slope entries
  # each new slope is measured at next self.DX distance
  # input slope yp (um/m) micrometers per meter
  def enter_slope(self, int_yp: int):
    if self.I >= self.full_seg_size:
      self.I = self.full_seg_size
      # calculate position to remove from history
      prev_ptr = (self.ptr + self.buf_size - self.full_seg_size) % self.buf_size
      prev_rvz = self.buf_rvz[prev_ptr]
      self.RS -= prev_rvz
    else:
      self.I += 1
    self.X += self.interval_mm
    # calculate new rvz (RS increment)
    int_rvz = abs(self.vz_from_slope(int_yp))
    self.RS += int_rvz
    self.buf_rvz[self.ptr] = int_rvz
    self.ptr = (self.ptr + 1) % self.buf_size

  def IRI(self):
    if self.I < 1:
      return 0.0 # avoid division by zero
    # TODO why factor 10 - probably wtp-46 coefficients are so
    return self.RS / self.scale_int_z / self.I
