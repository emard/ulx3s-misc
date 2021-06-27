library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
--use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all; -- for real numbers

package coefficients is
type coefficients_type is array(0 to 16+4+6*4-1) of real;
constant coefficients_250mm_matrix: coefficients_type := (
-- ST matrix 4x4
  0.9966071  ,  1.091514e-2, -2.083274e-3,  3.190145e-4  , -- 0*4+
 -0.5563044  ,  0.9438768  , -0.8324718  ,  5.064701e-2  , -- 1*4+
  2.153176e-2,  2.126763e-3,  0.7508714  ,  8.221888e-3  , -- 2*4+
  3.335013   ,  0.3376467  ,-39.12762    ,  0.4347564    , -- 3*4+
-- PR matrix 1x4
  5.476107e-3,  1.388776   ,  0.2275968  , 35.79262      , -- 4*4+
others => 0.0 -- 5*4+ .. 10*4+ variable area
);
end coefficients;
