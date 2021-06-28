library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
--use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all; -- for real numbers

package coefficients is
type coefficients_type is array(0 to 17*4-1) of real;
constant coefficients_250mm_matrix: coefficients_type := (
-- 0*4 ST matrix 4x4
  0.9966071  ,  1.091514e-2, -2.083274e-3,  3.190145e-4, -- 0*4+
 -0.5563044  ,  0.9438768  , -0.8324718  ,  5.064701e-2, -- 1*4+
  2.153176e-2,  2.126763e-3,  0.7508714  ,  8.221888e-3, -- 2*4+
  3.335013   ,  0.3376467  ,-39.12762    ,  0.4347564  , -- 3*4+
-- 4*4 PR matrix 1x4
  5.476107e-3,  1.388776   ,  0.2275968  , 35.79262    , -- 4*4+
-- 5*4
  0.0        ,  0.0        ,  0.0        ,  0.0        ,
  0.0        ,  0.0        ,  0.0        ,  0.0        ,
  0.0        ,  0.0        ,  0.0        ,  0.0        ,
  0.0        ,  0.0        ,  0.0        ,  0.0        ,
  0.0        ,  0.0        ,  0.0        ,  0.0        ,
  0.0        ,  0.0        ,  0.0        ,  0.0        ,
-- 11*4
  0.1        ,  0.2        ,  0.3        ,  0.4        ,
  0.0        ,  0.0        ,  0.0        ,  0.0        ,
  0.0        ,  0.0        ,  0.0        ,  0.0        ,
  0.0        ,  0.0        ,  0.0        ,  0.0        ,
  0.0        ,  0.0        ,  0.0        ,  0.0        ,
  0.0        ,  0.0        ,  0.0        ,  0.0        ,
--
others => 0.0 -- 5*4+ .. 16*4+ Z0=5*4 and Z1=11*4 variable area
);

-- python3 to verify result (may differ in last digit due to roundoff)
-- use result <= z0; debug line
-- >>> "%08X" % (int( (5.476107e-3 * 1 + 0.9966071 * 0.1 + 1.091514e-2 * 0.2 + -2.083274e-3 * 0.3 + 3.190145e-4 * 0.4 ) * (1<<20) ) + 0x100000000 & 0xFFFFFFFF)
-- '0001B589'
-- LCD shows:
-- 9001B58B with result <= z0
-- FFFA5E9B with result <= z0-c initially (BTN1 not pressed)
-- FFF32EB4 / FFF6351A alternating with result <= z0-c after 16 and more BTN1 presses
--
-- microcode to calculate one step
-- swap_z = 0                 C  = 0  , A = M[0+4*4], B = YP
-- Z0[0]  =   PR[0] * YP      C += A*B, A = M[0+0*4], B = M[0+11*4]
-- Z0[0] += ST[0,0] * Z1[0]   C += A*B, A = M[1+0*4], B = M[1+11*4]
-- Z0[0] += ST[0,1] * Z1[1]   C += A*B, A = M[2+0*4], B = M[2+11*4]
-- Z0[0] += ST[0,2] * Z1[2]   C += A*B, A = M[3+0*4], B = M[3+11*4]
-- Z0[0] += ST[0,3] * Z1[3]   M[0+5*4] = C
--                            C  = 0  , A = M[1+4*4], B = YP
-- Z0[1]  =   PR[1] * YP      C += A*B, A = M[0+1*4], B = M[0+11*4]
-- Z0[1] += ST[1,0] * Z1[0]   C += A*B, A = M[1+1*4], B = M[1+11*4]
-- Z0[1] += ST[1,1] * Z1[1]   C += A*B, A = M[2+1*4], B = M[2+11*4]
-- Z0[1] += ST[1,2] * Z1[2]   C += A*B, A = M[3+1*4], B = M[3+11*4]
-- Z0[1] += ST[1,3] * Z1[3]   M[1+5*4] = C
--                            C  = 0  , A = M[2+4*4], B = YP
-- Z0[2]  =   PR[2] * YP      C += A*B, A = M[0+2*4], B = M[0+11*4]
-- Z0[2] += ST[2,0] * Z1[0]   C += A*B, A = M[1+2*4], B = M[1+11*4]
-- Z0[2] += ST[2,1] * Z1[1]   C += A*B, A = M[2+2*4], B = M[2+11*4]
-- Z0[2] += ST[2,2] * Z1[2]   C += A*B, A = M[3+2*4], B = M[3+11*4]
-- Z0[2] += ST[2,3] * Z1[3]   M[2+5*4] = C
--                            C  = 0  , A = M[3+4*4], B = YP
-- Z0[3]  =   PR[3] * YP      C += A*B, A = M[0+3*4], B = M[0+11*4]
-- Z0[3] += ST[3,0] * Z1[0]   C += A*B, A = M[1+3*4], B = M[1+11*4]
-- Z0[3] += ST[3,1] * Z1[1]   C += A*B, A = M[2+3*4], B = M[2+11*4]
-- Z0[3] += ST[3,2] * Z1[2]   C += A*B, A = M[3+3*4], B = M[3+11*4]
-- Z0[3] += ST[3,3] * Z1[3]   M[3+5*4] = C
-- swap_z = 1                 C  = 0  , A = M[0+4*4], B = YP
-- Z1[0]  =   PR[0] * YP      C += A*B, A = M[0+0*4], B = M[0+5*4]
-- Z1[0] += ST[0,0] * Z0[0]   C += A*B, A = M[1+0*4], B = M[1+5*4]
-- Z1[0] += ST[0,1] * Z0[1]   C += A*B, A = M[2+0*4], B = M[2+5*4]
-- Z1[0] += ST[0,2] * Z0[2]   C += A*B, A = M[3+0*4], B = M[3+5*4]
-- Z1[0] += ST[0,3] * Z0[3]   M[0+11*4] = C
--                            C  = 0  , A = M[1+4*4], B = YP
-- Z1[1]  =   PR[1] * YP      C += A*B, A = M[0+1*4], B = M[0+5*4]
-- Z1[1] += ST[1,0] * Z0[0]   C += A*B, A = M[1+1*4], B = M[1+5*4]
-- Z1[1] += ST[1,1] * Z0[1]   C += A*B, A = M[2+1*4], B = M[2+5*4]
-- Z1[1] += ST[1,2] * Z0[2]   C += A*B, A = M[3+1*4], B = M[3+5*4]
-- Z1[1] += ST[1,3] * Z0[3]   M[1+11*4] = C
--                            C  = 0  , A = M[2+4*4], B = YP
-- Z1[2]  =   PR[2] * YP      C += A*B, A = M[0+2*4], B = M[0+5*4]
-- Z1[2] += ST[2,0] * Z0[0]   C += A*B, A = M[1+2*4], B = M[1+5*4]
-- Z1[2] += ST[2,1] * Z0[1]   C += A*B, A = M[2+2*4], B = M[2+5*4]
-- Z1[2] += ST[2,2] * Z0[2]   C += A*B, A = M[3+2*4], B = M[3+5*4]
-- Z1[2] += ST[2,3] * Z0[3]   M[2+11*4] = C
--                            C  = 0  , A = M[3+4*4], B = YP
-- Z1[3]  =   PR[3] * YP      C += A*B, A = M[0+3*4], B = M[0+5*4]
-- Z1[3] += ST[3,0] * Z0[0]   C += A*B, A = M[1+3*4], B = M[1+5*4]
-- Z1[3] += ST[3,1] * Z0[1]   C += A*B, A = M[2+3*4], B = M[2+5*4]
-- Z1[3] += ST[3,2] * Z0[2]   C += A*B, A = M[3+3*4], B = M[3+5*4]
-- Z1[3] += ST[3,3] * Z0[3]   M[3+11*4] = C
end coefficients;
