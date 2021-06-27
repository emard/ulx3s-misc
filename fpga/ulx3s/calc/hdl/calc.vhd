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
  enter: in std_logic;
  yp: in  std_logic_vector(31 downto 0);
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
  signal a,b,ra,rb,c: signed(31 downto 0);
  signal ab: signed(63 downto 0);
  signal result: signed(31 downto 0);
  signal reset_c, calc_c: std_logic;
  constant cnt_bits: integer := 6; -- 0-31, stop at 32
  signal cnt: unsigned(cnt_bits-1 downto 0);
  signal ia, ib: unsigned(6 downto 0); -- indexes for matrix
  signal matrix_read, matrix_write: std_logic := '0';
  signal mux_ab: unsigned(1 downto 0) := "00";
begin
  --d0 <= std_logic_vector(int32_coefficients_matrix(to_integer(unsigned(d1))));
  --d0 <= std_logic_vector(bc(31 downto 0));
  d0 <= std_logic_vector(result);
  
  -- data fetch, this should create BRAM
  process(clk)
  begin
    if rising_edge(clk) then
      --if matrix_read = '1' then
        ra <= int32_coefficients_matrix(to_integer(ia));
        rb <= int32_coefficients_matrix(to_integer(ib));
      --end if;
      if matrix_write = '1' then
        int32_coefficients_matrix(to_integer(ia)) <= c;
      end if;
    end if;
  end process;
  
  -- mux for a,b
  process(clk)
  begin
    if rising_edge(clk) then
      case mux_ab is
        when "10" => -- a from matrix ra, b from input yp
          a <= ra;
          b <= signed(yp);
        when "11" => -- a,b from matrix ra,rb
          a <= ra;
          b <= rb;
        when others => -- "00" NOP
      end case;
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
  
  -- 16 iterations for one row
  --  4 iterations for 4 rows
  -- 64 cycles total
  process(clk)
  begin
    if rising_edge(clk) then
      if enter = '1' then
        cnt <= (others => '0');
      else
        case cnt(2 downto 0) is
          when "000" => -- 0
            --if cnt(cnt_bits-1 downto 3) = (others => '0') then
              reset_c <= '1';
              ia <= to_unsigned(0+ 4*4, 7); -- PR(0)
              ib <= to_unsigned(0+11*4, 7); -- Z1(0)
            --else
            --end if;
          when "001" => -- 1
            reset_c <= '0';
            matrix_read <= '1';
          when "010" => -- 2
            matrix_read <= '0';
            mux_ab <= "10"; -- a,b <= ra,yp
          when "011" => -- 3
            mux_ab <= "00"; -- NOP
            calc_c <= '1';  -- PR(0)*YP or ST(0,0)*Z1(0)
          when "100" => -- 4
            calc_c <= '0';
          when "101" => -- 5
            result <= c;
            matrix_write <= '1';
          when "110" => -- 6
            matrix_write <= '0';
          when others =>
        end case;
        if cnt(cnt_bits-1) = '0' then
          cnt <= cnt + 1;
        end if;
      end if;
    end if;
  end process;
  
end;
