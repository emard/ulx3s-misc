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
  clk: in std_logic;
  start: in std_logic;
  d1: in  std_logic_vector(31 downto 0);
  d0: out std_logic_vector(31 downto 0)
);
end;

architecture RTL of calc is
  constant c_b: integer := 0;
  constant int_scale_matrix_2n: integer := 20; -- approx 1e6
  type int32_coefficients_type is array(0 to 17*4-1) of signed(31 downto 0);
  -- function to scale and convert real matrix to integers
  function matrix_real2int(x: coefficients_type; scale: integer)
    return int32_coefficients_type is
      variable i, j: integer;
      variable    y: int32_coefficients_type;
    begin
      for i in 0 to 3 loop
        for j in 0 to 16 loop
          y(i+4*j) := to_signed(integer(x(i+4*j)*real(scale)),32);
        end loop;
      end loop;
    return y;
  end matrix_real2int;
  signal int32_coefficients_matrix: int32_coefficients_type := 
    matrix_real2int(coefficients_250mm_matrix, 2**int_scale_matrix_2n);
  signal a,b,c: signed(31 downto 0);
  signal ab: signed(63 downto 0);
  signal result: signed(31 downto 0);
  signal reset_c, calc_c: std_logic;
  signal cnt: unsigned(3 downto 0);
  signal ia, ib: unsigned(6 downto 0); -- indexes for matrix
  signal matrix_read, matrix_write: std_logic := '0';
begin
  --d0 <= std_logic_vector(int32_coefficients_matrix(to_integer(unsigned(d1))));
  --d0 <= std_logic_vector(bc(31 downto 0));
  d0 <= std_logic_vector(result);
  
  -- indexes for data fetch, BRAM
  process(clk)
  begin
    if rising_edge(clk) then
      if matrix_read = '1' then
        a <= int32_coefficients_matrix(to_integer(ia));
        b <= int32_coefficients_matrix(to_integer(ib));
      end if;
      if matrix_write = '1' then
        int32_coefficients_matrix(to_integer(ia)) <= c;
      end if;
    end if;
  end process;

  -- sum of scaled integer multiplication
  ab <= a*b;
  process(clk)
  begin
    if rising_edge(clk) then
      if reset_c = '1' then
        c <= (others => '0');
      else
        if calc_c = '1' then
          c <= c+ab(int_scale_matrix_2n+31 downto int_scale_matrix_2n);
        end if;
      end if;
    end if;
  end process;
  
  --b <= x"00200000"; -- 2.0 scaled fixed point 20-bit
  --c <= x"00000030";
  
  process(clk)
  begin
    if rising_edge(clk) then
      if start = '1' then
        cnt <= (others => '0');
      else
        if cnt = x"0" then
          reset_c <= '1';
          ia <= to_unsigned(0, 7);
          ib <= to_unsigned(1, 7);
        else
          reset_c <= '0';
          if cnt = x"5" then
            ia <= to_unsigned(5*4, 7);
          end if;
        end if;
        if cnt = x"1" then
          matrix_read <= '1';
        else
          matrix_read <= '0';
        end if;
        if cnt = x"2" then
          calc_c <= '1';
        else
          calc_c <= '0';
        end if;
        if cnt = x"4" then
          result <= c;
        end if;
        if cnt = x"6" then
          matrix_write <= '1';
        else
          matrix_write <= '0';
        end if;
        if cnt(3) = '0' then
          cnt <= cnt + 1;
        end if;
      end if;
    end if;
  end process;
  
end;
