-- response calculator
-- (c) Davor Jadrijevic
-- LICENSE=BSD

--- enter slope, in 177 clk cycles calculates vz response

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
  --length_m    : integer := 100  --  m length
  length_m    : integer := 1  --  m length DEBUG
);
port (
  clk: in std_logic;
  enter: in std_logic; -- '1' to enter slope for every sampling interval x = 250 mm
  slope_l, slope_r: in  std_logic_vector(31 downto 0); -- slope um/m
     vz_l,    vz_r: out std_logic_vector(31 downto 0); -- z-velocity um/s
   srvz_l,  srvz_r: out std_logic_vector(31 downto 0); -- z-velocity um/s
  d0, d1, d2, d3: out std_logic_vector(31 downto 0)
);
end;

architecture RTL of calc is
  constant int_scale_matrix_2n: integer := 20; -- approx 1e6
  type int32_coefficients_type is array(0 to 2047) of signed(31 downto 0); -- 12*4 for matrix calc + 2*512 for running sum l,r
  -- function to scale and convert real matrix to integers
  function matrix_real2int(x: coefficients_type; scale: integer)
    return int32_coefficients_type is
      variable i, j: integer;
      variable    y: int32_coefficients_type;
    begin
      for i in 0 to 3 loop
        for j in 0 to x'length/4-1 loop
          y(i+4*j) := to_signed(integer(x(i+4*j)*real(scale)),32);
        end loop;
        for j in x'length/4 to y'length/4-1 loop
          y(i+4*j) := (others => '0');
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
  constant cnt_bits: integer := 9; -- 0-256, stop at 511 (some skipped)
  signal cnt: unsigned(cnt_bits-1 downto 0) := (others => '1'); -- don't start before enter
  alias cnt_element: unsigned(1 downto 0) is cnt(1 downto 0); -- 0-3 one element calc
  alias cnt_row    : unsigned(4 downto 2) is cnt(4 downto 2); -- 0-4 one row    of ST
  alias cnt_col    : unsigned(6 downto 5) is cnt(6 downto 5); -- 0-3 one column of ST
  alias cnt_ch     : unsigned(7 downto 7) is cnt(7 downto 7); -- 0-1 two channels
  alias cnt_above_row : unsigned(cnt_bits-1 downto cnt_element'length+cnt_row'length) is cnt(cnt_bits-1 downto cnt_element'length+cnt_row'length);
  constant n_points: integer := length_m*1000/interval_mm; -- default 400 points for 250 mm interval
  --constant i_points: unsigned(8 downto 0) := to_unsigned(512-n_points, 9);
  signal ia, ib: unsigned(10 downto 0); -- indexes for matrix 0-2047
  signal irs_head: unsigned(8 downto 0) := to_unsigned(n_points, 9); -- head index running sum 0-511
  signal irs_tail: unsigned(8 downto 0) := (others => '0'); -- tail index running sum 0-511
  signal matrix_write: std_logic := '0';
  signal swap_z: std_logic := '1'; -- swaps Z0 or Z1
  type z_type is array(0 to 3) of signed(31 downto 0);
  signal z: z_type;
  type vz_type is array(0 to 1) of signed(31 downto 0);
  signal vz, rvz, srvz: vz_type := (others => (others => '0'));
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
      if enter = '1' and cnt(cnt_bits-1 downto cnt_bits-2) = "11" then
        cnt <= (others => '0');
        swap_z <= not swap_z;
        ypl <= signed(slope_l);
        ypr <= signed(slope_r);
      else
        if cnt(cnt_bits-1) = '0' then
          case cnt_element is -- one element calc
            when "00" => -- 0 = cnt_element
              matrix_write <= '0'; -- after state "11"
              case cnt_row is -- one row of ST
                when "000" => -- 0
                  c <= (others => '0');
                  ia <= "00000" & x"4" & cnt_col; -- PR(i) one columnt of ST
                when "001" => -- 1
                  ia <= "00000" & "00" & cnt_col & "00"; -- ST(i,0)
                  ib <= "00000" & "10" & (not swap_z) & cnt_ch & "00"; -- Zz(0)
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
                ib <= "00000" & "10" & swap_z & cnt_ch & cnt_col;
              end if;
            when "11" => -- 3 = cnt_element result ready
              --if cnt_row = "000" then -- debug store first value
              if cnt_row = "100" then -- normal store last value
                z(to_integer(unsigned(cnt_col))) <= c;
                if cnt_col = "10" then -- 2, Z(2)
                  vz(to_integer(unsigned(cnt_ch))) <= z(0)-c; -- vz = Z(0)-Z(2)
                end if;
                matrix_write <= '1'; -- matrix(ib) <= c
              end if;
            when others =>
          end case;
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
        else -- cnt(cnt_bits-1) = '1'
          -- matrix done
          -- run few cycles more for BRAM running average
          if cnt(cnt_bits-2) = '0' then
            case cnt(3 downto 0) is
              when x"0" =>
                ib <= "01" & irs_tail;
                rvz(0) <= abs(vz(0));
                c <= abs(vz(0)); -- data to store
              when x"2" =>
                -- running sum, subtract tail
                srvz(0) <= srvz(0)+c-rb; -- normal
                --srvz(0) <= c; -- debug
                --srvz(0) <= rb; -- debug
                --srvz(0) <= to_signed(0,32-11) & signed(ib); -- debug
              when x"3" =>
                ib <= "01" & irs_head; -- address to write
              when x"4" =>
                matrix_write <= '1';
              when x"5" =>
                matrix_write <= '0';
              -- -------------------
              when x"6" =>
                ib <= "10" & irs_tail;
                rvz(1) <= abs(vz(1));
                c <= abs(vz(1)); -- data to store
              when x"8" =>
                -- running sum, subtract tail
                srvz(1) <= srvz(1)+c-rb; -- normal
                --srvz(1) <= rb; -- debug
                --srvz(1) <= to_signed(0,32-11) & signed(ib); -- debug
              when x"9" =>
                ib <= "10" & irs_head; -- address to write
              when x"A" =>
                matrix_write <= '1';
              when x"B" =>
                matrix_write <= '0';
              when x"F" =>
                irs_head <= irs_head + 1; -- advance for the next time
                irs_tail <= irs_tail + 1;
                cnt(cnt_bits-2) <= '1'; -- end
              when others =>
            end case;
            cnt(3 downto 0) <= cnt(3 downto 0) + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- output connection
  vz_l <= std_logic_vector(vz(0));
  vz_r <= std_logic_vector(vz(1));

  --d0 <= std_logic_vector(int32_coefficients_matrix(to_integer(unsigned(d1))));
  --d0 <= std_logic_vector(bc(31 downto 0));

  --d0 <= std_logic_vector(z(0));
  --d1 <= std_logic_vector(z(1));
  --d2 <= std_logic_vector(z(2));
  --d3 <= std_logic_vector(z(3));

  d0 <= std_logic_vector(rvz(0));
  d1 <= std_logic_vector(rvz(1));
  d2 <= std_logic_vector(srvz(0));
  d3 <= std_logic_vector(srvz(1));
  
end;
