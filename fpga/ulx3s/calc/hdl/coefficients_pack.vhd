library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
--use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all; -- for real numbers

package coefficients is
type coefficients_type is array(0 to 3) of real;
constant coefficients_matrix: coefficients_type := (
1.0, 2.0, 3.0, 4.0,
others => 0.0
);
end coefficients;
