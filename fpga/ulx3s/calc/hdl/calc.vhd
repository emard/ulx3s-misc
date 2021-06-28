-- response calculator
-- (c) Davor Jadrijevic
-- LICENSE=BSD

--- enter slope, in 256 clk cycles calculates vz response

-- TODO:
-- [ ] extend 1-input to 6-input
-- [ ] speed up, reduce states
-- [ ] parameter for step (other than 250 mm)
-- [ ] function to calculate coefficients for arbitrary step
-- [ ] moving sum rvz in BRAM (parameter: track length 100 m)

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
  enter: in std_logic; -- '1' to enter slope for every x = 250 mm
  yp: in  std_logic_vector(31 downto 0); -- slope um/m
  vz: out std_logic_vector(31 downto 0); -- z-velocity um/s
  d0, d1, d2, d3: out std_logic_vector(31 downto 0)
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
  constant cnt_bits: integer := 9; -- 0-255, stop at 256
  signal cnt: unsigned(cnt_bits-1 downto 0);
  signal ia, ib: unsigned(6 downto 0); -- indexes for matrix
  signal matrix_read, matrix_write: std_logic := '0';
  signal mux_ab: unsigned(1 downto 0) := "00";
  signal swap_z: std_logic := '1'; -- swaps Z0 or Z1
  signal z0, z1, z2, z3: signed(31 downto 0);
begin
  
  -- data fetch, this should create BRAM
  process(clk)
  begin
    if rising_edge(clk) then
      ra <= int32_coefficients_matrix(to_integer(ia));
      rb <= int32_coefficients_matrix(to_integer(ib));
      if matrix_write = '1' then
        int32_coefficients_matrix(to_integer(ib)) <= c;
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

  -- 256 iterations  
  -- cnt(2 downto 0) 0-5 one element calc
  -- cnt(5 downto 3) 0-4 one row    of ST
  -- cnt(7 downto 6) 0-3 one column of ST
  process(clk)
  begin
    if rising_edge(clk) then
      if enter = '1' and cnt(cnt_bits-1) = '1' then
        cnt <= (others => '0');
        swap_z <= not swap_z;
      else
        case cnt(2 downto 0) is
          when "000" => -- 0
            case cnt(5 downto 3) is
              when "000" => -- 0
                reset_c <= '1';
                ia <= '0' & x"4" & cnt(7 downto 6); -- PR(i)
              when "001" => -- 1
                reset_c <= '0';
                ia <= '0' & "00" & cnt(7 downto 6) & "00"; -- ST(i,0)
                if swap_z = '1' then -- swap 5,B -- Zz(0) -> Z0(0) or Z1(0)
                  ib <= '0' & x"5" & "00"; -- Zz(0) -> Z0(0)
                  --ib <= to_unsigned(0+ 5*4, 7); -- Zz(0) -> Z0(0)
                else
                  ib <= '0' & x"B" & "00"; -- Zz(0) -> Z1(0)
                  --ib <= to_unsigned(0+11*4, 7); -- Zz(0) -> Z1(0)
                end if;
              when "010" | "011" | "100" => -- 2,3,4
                ia(1 downto 0) <= ia(1 downto 0) + 1; -- ST(i,1) ST(i,2) ST(i,3)
                ib(1 downto 0) <= ib(1 downto 0) + 1; --   Zz(1)   Zz(2)   Zz(3)
              when others =>
            end case;
          when "001" => -- 1
            reset_c <= '0';
            matrix_read <= '1';
          when "010" => -- 2
            matrix_read <= '0';
            if cnt(5 downto 3) = "000" then
              mux_ab <= "10"; -- a,b <= ra,yp
            else
              mux_ab <= "11"; -- a,b <= ra,rb
            end if;
          when "011" => -- 3
            mux_ab <= "00"; -- NOP
            calc_c <= '1';  -- PR(0)*YP or ST(0,0)*Z1(0)
          when "100" => -- 4
            calc_c <= '0';
            if cnt(5 downto 3) = "100" then -- set write address
              if swap_z = '1' then -- swap 5,B -- Z0(i) or Z1(i)
                ib <= '0' & x"B" & cnt(7 downto 6); -- Z1(i)
              else
                ib <= '0' & x"5" & cnt(7 downto 6); -- Z0(i)
              end if;
            end if;
          when "101" => -- 5 result ready
            --if cnt(5 downto 3) = "000" then -- debug store first value
            if cnt(5 downto 3) = "100" then -- normal store last value
              case cnt(7 downto 6) is
                when "00" => -- 0, Z(0)
                  z0 <= c;
                when "01" => -- 0, Z(1)
                  z1 <= c;
                when "10" => -- 2, Z(2)
                  z2 <= c;
                  result <= z0-c; -- vz = Z(0)-Z(2)
                when "11" => -- 3, Z(3)
                  z3 <= c;
                when others =>
              end case;
              matrix_write <= '1'; -- matrix(ib) <= c
            end if;
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

  -- output connection
  vz <= std_logic_vector(result);
  --d0 <= std_logic_vector(int32_coefficients_matrix(to_integer(unsigned(d1))));
  --d0 <= std_logic_vector(bc(31 downto 0));
  --d0 <= std_logic_vector(result);
  d0 <= std_logic_vector(z0);
  d1 <= std_logic_vector(z1);
  d2 <= std_logic_vector(z2);
  d3 <= std_logic_vector(z3);
  
end;
