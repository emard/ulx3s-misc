-- response calculator
-- (c) Davor Jadrijevic
-- LICENSE=BSD

library ieee;
use ieee.std_logic_1164.all;
-- use ieee.std_logic_arith.all; -- replaced by ieee.numeric_std.all
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use work.coefficients.all; -- coefficients matrix

entity calc is
generic (
  c_x: integer := 0;
  c_y: integer := 0
);
port (
  d1: in  std_logic_vector(31 downto 0);
  d0: out std_logic_vector(31 downto 0)
);
end;

architecture RTL of calc is
  constant c_b: integer := 0;
begin
  d0 <= d1;
end;
