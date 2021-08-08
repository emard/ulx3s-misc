library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
--use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all; -- for real numbers

package coefficients is

type coefficients_type is array(0 to 5*4-1) of real;

-- 50 mm (2000 samples in 100 m)
constant coefficients_50mm_matrix: coefficients_type := (
-- 0*4 ST matrix 4x4
  0.9998452  ,  2.235208e-3,  1.062545e-4,  1.476399e-5, -- 0*4+
 -0.1352583  ,  0.9870245  ,  7.098568e-2,  1.292695e-2, -- 1*4+
  1.030173e-3,  9.842664e-5,  0.9882941  ,  2.143501e-3, -- 2*4+
  0.8983268  ,  8.617964e-2,-10.2297     ,  0.9031446  , -- 3*4+
-- 4*4 PR matrix 1x4
  4.858894e-5,  6.427258e-2,  1.067582e-2,  9.331372     -- 4*4+
);

-- 195.3125 mm (512 samples in 100 m)
constant coefficients_195mm_matrix: coefficients_type := (
-- 0*4 ST matrix 4x4
  9.9785614e-01,  8.5793594e-03, -5.4978870e-04,  2.0366098e-04, -- 0*4+
 -4.5712855e-01,  9.5452636e-01, -4.2947561e-01,  4.2779926e-02, -- 1*4+
  1.3875682e-02,  1.3577397e-03,  8.4028977e-01,  6.9867568e-03, -- 2*4+
  2.8624663e+00,  2.8519952e-01, -3.3278152e+01,  5.6896591e-01, -- 3*4+
-- 4*4 PR matrix 1x4
  2.6934871e-03,  8.8660413e-01,  1.4583461e-01,  3.0415682e+01  -- 4*4+
);

-- 200 mm (500 samples in 100 m)
constant coefficients_200mm_matrix: coefficients_type := (
-- 0*4 ST matrix 4x4
  0.9977588  ,  8.780606e-3, -6.436089e-4,  2.127641e-4, -- 0*4+
 -0.4660258  ,  0.9535856  , -0.4602074  ,  4.352945e-2, -- 1*4+
  1.448438e-2,  1.418428e-3,  0.8332105  ,  7.105564e-3, -- 2*4+
  2.908761   ,  0.2901964  ,-33.84164    ,  0.5574984  , -- 3*4+
-- 4*4 PR matrix 1x4
  2.885245e-3,  0.9262331  ,  0.1523053  , 30.93289      -- 4*4+
);

-- 250 mm (400 samples in 100 m)
constant coefficients_250mm_matrix: coefficients_type := (
-- 0*4 ST matrix 4x4
  0.9966071  ,  1.091514e-2, -2.083274e-3,  3.190145e-4, -- 0*4+
 -0.5563044  ,  0.9438768  , -0.8324718  ,  5.064701e-2, -- 1*4+
  2.153176e-2,  2.126763e-3,  0.7508714  ,  8.221888e-3, -- 2*4+
  3.335013   ,  0.3376467  ,-39.12762    ,  0.4347564  , -- 3*4+
-- 4*4 PR matrix 1x4
  5.476107e-3,  1.388776   ,  0.2275968  , 35.79262      -- 4*4+
);

constant coefficients_250mm_matrix_debug: coefficients_type := (
-- 0*4 ST matrix 4x4
  0.9966071  ,  1.091514e-2, -2.083274e-3,  3.190145e-4, -- 0*4+
 -0.5563044  ,  0.9438768  , -0.8324718  ,  5.064701e-2, -- 1*4+
  2.153176e-2,  2.126763e-3,  0.7508714  ,  8.221888e-3, -- 2*4+
  3.335013   ,  0.3376467  ,-39.12762    ,  0.4347564  , -- 3*4+
-- 4*4 PR matrix 1x4
  5.476107e-3,  1.388776   ,  0.2275968  , 35.79262    , -- 4*4+
-- variable area
--  5*4 unused, start Z from 8*4 to simplify code
--  0.0        ,  0.0        ,  0.0        ,  0.0        , -- 5*4+
--  0.0        ,  0.0        ,  0.0        ,  0.0        , -- 6*4+
--  0.0        ,  0.0        ,  0.0        ,  0.0        , -- 7*4+
--  8*4 -- Z0
--  0.0        ,  0.0        ,  0.0        ,  0.0        , -- 8*4+ Z0 left
--  0.0        ,  0.0        ,  0.0        ,  0.0        , -- 9*4+ Z0 right
-- 10*4 -- Z1
--  0.0        ,  0.0        ,  0.0        ,  0.0        , -- 10*4+ Z1 left
--  0.0        ,  0.0        ,  0.0        ,  0.0        , -- 11*4+ Z1 right
--   12*4 ..  511*4 unused
--  512*4 .. 1023*4 rvz_l log (for running sum)
-- 1024*4 .. 1535*4 rvz_r log (for running sum)
-- 1536*4 .. 2047*4 unused
others => 0.0
);

constant  interval_mm : integer :=  50; -- mm sampling interval (edit also esp32btgps.ino G_RANGE)
constant  length_m    : integer := 100; --  m length

-- choose one 50-250 mm depending on interval_mm
constant coefficients_active_matrix: coefficients_type :=
--  coefficients_250mm_matrix;
--  coefficients_200mm_matrix;
--  coefficients_195mm_matrix;
  coefficients_50mm_matrix;

-- python3 to verify result (may differ in last digit due to roundoff)
-- use result <= z0; debug line
-- .yp(32'h00100000), (1.0 scaled to 1<<20)
-- >>> "%08X" % (int( (5.476107e-3 * 1 + 0.9966071 * 0.1 + 1.091514e-2 * 0.2 + -2.083274e-3 * 0.3 + 3.190145e-4 * 0.4 ) * (1<<20) ) + 0x100000000 & 0xFFFFFFFF)
-- '0001B589'
-- LCD shows:
-- 9001B58B with result <= z0
-- FFFA5E9B with result <= z0-c initially (BTN1 not pressed)
-- FFF32EB4 / FFF6351A alternating with result <= z0-c after 16 and more BTN1 presses
--
-- microcode to calculate one step
-- swap_z = 0                 C  = 0  , A = M[0+4*4], B = YP
-- Z0[0]  =   PR[0] * YP      C += A*B, A = M[0+0*4], B = M[0+10*4]
-- Z0[0] += ST[0,0] * Z1[0]   C += A*B, A = M[1+0*4], B = M[1+10*4]
-- Z0[0] += ST[0,1] * Z1[1]   C += A*B, A = M[2+0*4], B = M[2+10*4]
-- Z0[0] += ST[0,2] * Z1[2]   C += A*B, A = M[3+0*4], B = M[3+10*4]
-- Z0[0] += ST[0,3] * Z1[3]   M[0+8*4] = C
--                            C  = 0  , A = M[1+4*4], B = YP
-- Z0[1]  =   PR[1] * YP      C += A*B, A = M[0+1*4], B = M[0+10*4]
-- Z0[1] += ST[1,0] * Z1[0]   C += A*B, A = M[1+1*4], B = M[1+10*4]
-- Z0[1] += ST[1,1] * Z1[1]   C += A*B, A = M[2+1*4], B = M[2+10*4]
-- Z0[1] += ST[1,2] * Z1[2]   C += A*B, A = M[3+1*4], B = M[3+10*4]
-- Z0[1] += ST[1,3] * Z1[3]   M[1+8*4] = C
--                            C  = 0  , A = M[2+4*4], B = YP
-- Z0[2]  =   PR[2] * YP      C += A*B, A = M[0+2*4], B = M[0+10*4]
-- Z0[2] += ST[2,0] * Z1[0]   C += A*B, A = M[1+2*4], B = M[1+10*4]
-- Z0[2] += ST[2,1] * Z1[1]   C += A*B, A = M[2+2*4], B = M[2+10*4]
-- Z0[2] += ST[2,2] * Z1[2]   C += A*B, A = M[3+2*4], B = M[3+10*4]
-- Z0[2] += ST[2,3] * Z1[3]   M[2+8*4] = C
--                            C  = 0  , A = M[3+4*4], B = YP
-- Z0[3]  =   PR[3] * YP      C += A*B, A = M[0+3*4], B = M[0+10*4]
-- Z0[3] += ST[3,0] * Z1[0]   C += A*B, A = M[1+3*4], B = M[1+10*4]
-- Z0[3] += ST[3,1] * Z1[1]   C += A*B, A = M[2+3*4], B = M[2+10*4]
-- Z0[3] += ST[3,2] * Z1[2]   C += A*B, A = M[3+3*4], B = M[3+10*4]
-- Z0[3] += ST[3,3] * Z1[3]   M[3+8*4] = C
-- swap_z = 1                 C  = 0  , A = M[0+4*4], B = YP
-- Z1[0]  =   PR[0] * YP      C += A*B, A = M[0+0*4], B = M[0+8*4]
-- Z1[0] += ST[0,0] * Z0[0]   C += A*B, A = M[1+0*4], B = M[1+8*4]
-- Z1[0] += ST[0,1] * Z0[1]   C += A*B, A = M[2+0*4], B = M[2+8*4]
-- Z1[0] += ST[0,2] * Z0[2]   C += A*B, A = M[3+0*4], B = M[3+8*4]
-- Z1[0] += ST[0,3] * Z0[3]   M[0+10*4] = C
--                            C  = 0  , A = M[1+4*4], B = YP
-- Z1[1]  =   PR[1] * YP      C += A*B, A = M[0+1*4], B = M[0+8*4]
-- Z1[1] += ST[1,0] * Z0[0]   C += A*B, A = M[1+1*4], B = M[1+8*4]
-- Z1[1] += ST[1,1] * Z0[1]   C += A*B, A = M[2+1*4], B = M[2+8*4]
-- Z1[1] += ST[1,2] * Z0[2]   C += A*B, A = M[3+1*4], B = M[3+8*4]
-- Z1[1] += ST[1,3] * Z0[3]   M[1+10*4] = C
--                            C  = 0  , A = M[2+4*4], B = YP
-- Z1[2]  =   PR[2] * YP      C += A*B, A = M[0+2*4], B = M[0+8*4]
-- Z1[2] += ST[2,0] * Z0[0]   C += A*B, A = M[1+2*4], B = M[1+8*4]
-- Z1[2] += ST[2,1] * Z0[1]   C += A*B, A = M[2+2*4], B = M[2+8*4]
-- Z1[2] += ST[2,2] * Z0[2]   C += A*B, A = M[3+2*4], B = M[3+8*4]
-- Z1[2] += ST[2,3] * Z0[3]   M[2+10*4] = C
--                            C  = 0  , A = M[3+4*4], B = YP
-- Z1[3]  =   PR[3] * YP      C += A*B, A = M[0+3*4], B = M[0+8*4]
-- Z1[3] += ST[3,0] * Z0[0]   C += A*B, A = M[1+3*4], B = M[1+8*4]
-- Z1[3] += ST[3,1] * Z0[1]   C += A*B, A = M[2+3*4], B = M[2+8*4]
-- Z1[3] += ST[3,2] * Z0[2]   C += A*B, A = M[3+3*4], B = M[3+8*4]
-- Z1[3] += ST[3,3] * Z0[3]   M[3+10*4] = C
end coefficients;
