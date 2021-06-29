-- response calculator
-- (c) Davor Jadrijevic
-- LICENSE=BSD

--- enter slope, in 160 clk cycles calculates vz response

-- TODO:
-- [x] extend 1-input to 2-input
-- [x] speed up, reduce states
-- [x] alias element calc state index cnt(2 downto 0) -> cnt(1 downto 0)
-- [x] reduce address bits 7->6 ia,ib
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
  interval_mm : integer := 250; -- mm sampling interval (don't touch)
  length_m    : integer := 100  --  m length
);
port (
  clk: in std_logic;
  enter: in std_logic; -- '1' to enter slope for every sampling interval x = 250 mm
  slope_l, slope_r: in  std_logic_vector(31 downto 0); -- slope um/m
     vz_l,    vz_r: out std_logic_vector(31 downto 0); -- z-velocity um/s
  d0, d1, d2, d3: out std_logic_vector(31 downto 0)
);
end;

architecture RTL of calc is
  constant c_b: integer := 0;
  constant int_scale_matrix_2n: integer := 20; -- approx 1e6
  type int32_coefficients_type is array(0 to 12*4-1) of signed(31 downto 0);
  -- function to scale and convert real matrix to integers
  function matrix_real2int(x: coefficients_type; scale: integer)
    return int32_coefficients_type is
      variable i, j: integer;
      variable    y: int32_coefficients_type;
    begin
      for i in 0 to 3 loop
        for j in 0 to 11 loop
          y(i+4*j) := to_signed(integer(x(i+4*j)*real(scale)),32);
        end loop;
      end loop;
    return y;
  end matrix_real2int;
  signal int32_coefficients_matrix: int32_coefficients_type := 
    matrix_real2int(coefficients_250mm_matrix, 2**int_scale_matrix_2n);
  signal ypl, ypr: signed(31 downto 0); -- slope registers
  signal yp: signed(31 downto 0); -- slope register
  signal a,b,ra,rb,c,c_calc: signed(31 downto 0);
  signal ab: signed(63 downto 0);
  type result_type is array(0 to 1) of signed(31 downto 0);
  signal result: result_type;
  constant cnt_bits: integer := 9; -- 0-256, stop at 511 (some skipped)
  signal cnt: unsigned(cnt_bits-1 downto 0) := (others => '1'); -- don't start before enter
  alias cnt_element: unsigned(1 downto 0) is cnt(1 downto 0); -- 0-3 one element calc
  alias cnt_row    : unsigned(4 downto 2) is cnt(4 downto 2); -- 0-4 one row    of ST
  alias cnt_col    : unsigned(6 downto 5) is cnt(6 downto 5); -- 0-3 one column of ST
  alias cnt_ch     : unsigned(7 downto 7) is cnt(7 downto 7); -- 0-1 two channels
  alias cnt_above_row : unsigned(cnt_bits-1 downto cnt_element'length+cnt_row'length) is cnt(cnt_bits-1 downto cnt_element'length+cnt_row'length);
  signal ia, ib: unsigned(5 downto 0); -- indexes for matrix
  signal matrix_write: std_logic := '0';
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

  yp <= signed(ypr) when cnt_ch = "1" else signed(ypl);
  a <= ra;
  b <= signed(yp) when cnt_row = "000" else rb;
  -- sum of scaled integer multiplication
  ab <= a*b;
  c_calc <= c+ab(int_scale_matrix_2n+31 downto int_scale_matrix_2n);

  -- 4*5*4*2=160 iterations
  -- cnt(2 downto 0) 0-3 one element calc
  -- cnt(5 downto 3) 0-4 one row    of ST
  -- cnt(7 downto 6) 0-3 one column of ST
  -- cnt(8)          0-1 two channels
  process(clk)
  begin
    if rising_edge(clk) then
      if enter = '1' and cnt(cnt_bits-1) = '1' then
        cnt <= (others => '0');
        swap_z <= not swap_z;
        ypl <= signed(slope_l);
        ypr <= signed(slope_r);
      else
        case cnt_element is -- one element calc
          when "00" => -- 0 = cnt_element
            matrix_write <= '0'; -- after state "11"
            case cnt_row is -- one row of ST
              when "000" => -- 0
                c <= (others => '0');
                ia <= x"4" & cnt_col; -- PR(i) one columnt of ST
              when "001" => -- 1
                ia <= "00" & cnt_col & "00"; -- ST(i,0)
                ib <= "10" & (not swap_z) & cnt_ch & "00"; -- Zz(0)
                -- ib <= to_unsigned((2*swap_z + cnt_ch + 8)*4, 7); -- Zz(0) -> Z0(0)
              when "010" | "011" | "100" => -- 2,3,4
                ia(1 downto 0) <= ia(1 downto 0) + 1; -- ST(i,1) ST(i,2) ST(i,3)
                ib(1 downto 0) <= ib(1 downto 0) + 1; --   Zz(1)   Zz(2)   Zz(3)
              when others =>
            end case;
          --when "01" => -- 1 = cnt_element
          -- must wait 1 clk for matrix read and calc here
          when "10" => -- 2 = cnt_element
            c <= c_calc; -- PR(0)*YP or ST(0,0)*Z1(0)
            if cnt_row = "100" then -- set write address
              ib <= "10" & swap_z & cnt_ch & cnt_col;
            end if;
          when "11" => -- 3 = cnt_element result ready
            --if cnt_row = "000" then -- debug store first value
            if cnt_row = "100" then -- normal store last value
              case cnt_col is
                when "00" => -- 0, Z(0)
                  z0 <= c;
                when "01" => -- 1, Z(1)
                  z1 <= c;
                when "10" => -- 2, Z(2)
                  z2 <= c;
                  result(to_integer(unsigned(cnt_ch))) <= z0-c; -- vz = Z(0)-Z(2)
                when "11" => -- 3, Z(3)
                  z3 <= c;
                when others =>
              end case;
              matrix_write <= '1'; -- matrix(ib) <= c
            end if;
          when others =>
        end case;
        if cnt(cnt_bits-1) = '0' then
          if cnt_element = "11" then -- skip states after 3
            cnt_element <= "00";
            if cnt_row = "100" then -- skip states after 4
              cnt_row <= "000";
              cnt_above_row <= cnt_above_row + 1;
            else
              cnt_row <= cnt_row + 1;
            end if;
          else
            cnt_element <= cnt_element + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- output connection
  vz_l <= std_logic_vector(result(0));
  vz_r <= std_logic_vector(result(1));

  --d0 <= std_logic_vector(int32_coefficients_matrix(to_integer(unsigned(d1))));
  --d0 <= std_logic_vector(bc(31 downto 0));
  --d0 <= std_logic_vector(result);
  d0 <= std_logic_vector(z0);
  d1 <= std_logic_vector(z1);
  d2 <= std_logic_vector(z2);
  d3 <= std_logic_vector(z3);
  
end;
