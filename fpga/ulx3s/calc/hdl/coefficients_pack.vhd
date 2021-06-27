library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
--use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all; -- for real numbers

package coefficients is
type coefficients_type is array(0 to 19) of real;
constant coefficients_matrix: coefficients_type := (
-- ST matrix 4x4
1.1, 2.1, 3.1, 4.1,
1.2, 2.2, 3.2, 4.2,
1.3, 2.3, 3.3, 4.3,
1.4, 2.4, 3.4, 4.4,
-- PR matrix 1x4
1.5, 2.5, 3.5, 4.5,
others => 0.0 -- should not be needed
);
end coefficients;
