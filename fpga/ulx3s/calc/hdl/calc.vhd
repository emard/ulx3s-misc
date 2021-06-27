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
  constant int_scale_matrix_2n: integer := 20; -- approx 1e6
  type uint32_coefficients_type is array(0 to 19) of unsigned(31 downto 0);
  -- function to scale and convert real matrix to integers
  function matrix_real2int(x: coefficients_type; scale: integer)
    return uint32_coefficients_type is
      variable i,j: integer;
      variable y: uint32_coefficients_type;
    begin
      for i in 0 to 3 loop
        for j in 0 to 4 loop
          y(i+4*j) := to_unsigned(integer(x(i+4*j)*real(scale)),32);
        end loop;
      end loop;
    return y;
  end matrix_real2int;
  constant uint32_coefficients_matrix: uint32_coefficients_type := 
    matrix_real2int(coefficients_matrix, 2**int_scale_matrix_2n);
begin
  --d0 <= d1;
  --d0 <= std_logic_vector(a00);
  d0 <= std_logic_vector(uint32_coefficients_matrix(4*4+0));
end;
