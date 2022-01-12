-- response calculator
-- (c) Davor Jadrijevic
-- LICENSE=BSD

--- enter slope, in 177 clk cycles calculates vz response

library ieee;
use ieee.std_logic_1164.all;
-- use ieee.std_logic_arith.all; -- replaced by ieee.numeric_std.all
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use work.coefficients.all; -- coefficients matrix

entity calc is
generic (
  int_scale_matrix_2n: integer := 20 -- approx 1e6 fixed precision
);
port (
  clk: in std_logic;
  enter: in std_logic; -- '1' to enter slope for every sampling interval x = 50 mm
  slope_l, slope_r: in  std_logic_vector(31 downto 0); -- [um/m] slope
     vz_l,    vz_r: out std_logic_vector(31 downto 0); -- [um/s] z-velocity signed
   srvz_l,  srvz_r: out std_logic_vector(31 downto 0); -- [um/m] IRI-100 rectified sum of z/x-velocities at (n_points*length_m)
  srvz2_l, srvz2_r: out std_logic_vector(31 downto 0); -- [um/m] IRI-20  rectified sum of z/x-velocities at (n_points2*length_m)
   -- iri[mm/m] = srvz/(1000*n_points) = srvz / 400e3
  ready: out std_logic; -- '1' when result is ready
  d0, d1, d2, d3: out std_logic_vector(31 downto 0)
);
end;

architecture RTL of calc is
  constant n_points: integer := length_m*1000/interval_mm; -- IRI-100 default 2000 points for 50 mm interval
  constant n_points2: integer := length2_m*1000/interval_mm; -- IRI-20 default 400 points for 50 mm interval
  constant matrix_size: integer := 12*4; -- storage size for matrix constants and variables
  constant total_size: integer := matrix_size+2*n_points; -- total storage size required for BRAM
  constant bram_addr_bits: integer := integer(ceil(log2(real(total_size)+0.5))); -- number of BRAM address bits
  type int32_coefficients_type is array(0 to total_size-1) of signed(31 downto 0); -- 12*4 for matrix calc + 2*n_points for running sum l,r
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
    matrix_real2int(coefficients_active_matrix, 2**int_scale_matrix_2n);
  signal ypl, ypr: signed(31 downto 0); -- slope registers
  signal yp: signed(31 downto 0); -- slope register
  signal a,b,ra,rb,c,c_calc: signed(31 downto 0);
  signal ab: signed(63 downto 0);
  signal ia, ib: unsigned(bram_addr_bits-1 downto 0); -- indexes for matrix calc and running sum
  -- running sum
  constant irs_min : unsigned(ib'length-2 downto 0) := to_unsigned(matrix_size/2, ib'length-1); -- first index set to skip matrix (/2 because ib=irs_head*2)
  constant irs_max : unsigned(ib'length-2 downto 0) := irs_min+n_points-1; -- last index: after this, wraparound to irs_min
  signal   irs_tail: unsigned(ib'length-2 downto 0) := irs_min+n_points2; -- tail index for running sum, initialized to min+n_points2 to be ahead of tail2
  --alias  irs_head  : unsigned(ib'length-2 downto 0) is irs_tail; -- same as tail
  signal   irs_tail2: unsigned(ib'length-2 downto 0) := irs_min; -- tail index for running sum, initialized to min
  -- state counter
  constant cnt_bits: integer := 9; -- 0-256, stop at 511 (some skipped) calc state counter
  signal cnt: unsigned(cnt_bits-1 downto 0) := (others => '1'); -- stopped state, don't start calc before enter
  alias cnt_element: unsigned(1 downto 0) is cnt(1 downto 0); -- 0-3 one element calc
  alias cnt_row    : unsigned(4 downto 2) is cnt(4 downto 2); -- 0-4 one row    of ST
  alias cnt_col    : unsigned(6 downto 5) is cnt(6 downto 5); -- 0-3 one column of ST
  alias cnt_ch     : unsigned(7 downto 7) is cnt(7 downto 7); -- 0-1 two channels
  alias cnt_above_row : unsigned(cnt_bits-1 downto cnt_element'length+cnt_row'length) is cnt(cnt_bits-1 downto cnt_element'length+cnt_row'length);
  constant cnt_pad0: unsigned(ia'length-1 downto cnt_ch'length+cnt_col'length+cnt_row'length) := (others => '0'); -- zero-pad high bits to make ia/ib address
  signal matrix_write: std_logic := '0';
  signal swap_z: std_logic := '1'; -- swaps Z0 or Z1
  type z_type is array(0 to 3) of signed(31 downto 0);
  signal z: z_type;
  type vz_type is array(0 to 1) of signed(31 downto 0);
  signal vz, rvz, srvz, srvz2: vz_type := (others => (others => '0'));
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
  -- sum of scaled integer multiplication, bugfix
  ab <= a*b; -- possible BUG with lattice diamond
  -- ab <= -(a*(-b)) when b<0 else a*b; -- same as a*b but BUG fixed
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
                  ia <= cnt_pad0 & x"4" & cnt_col; -- PR(i) one columnt of ST
                when "001" => -- 1
                  ia <= cnt_pad0 & "00" & cnt_col & "00"; -- ST(i,0)
                  ib <= cnt_pad0 & "10" & (not swap_z) & cnt_ch & "00"; -- Zz(0)
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
                ib <= cnt_pad0 & "10" & swap_z & cnt_ch & cnt_col;
              end if;
            when "11" => -- 3 = cnt_element result ready
              --if cnt_row = "000" then -- debug store first value
              if cnt_row = "100" then -- normal store last value
                z(to_integer(unsigned(cnt_col))) <= c;
                if cnt_col = "10" then -- 2, Z(2)
                  vz(to_integer(unsigned(cnt_ch))) <= z(0)-c; -- vz = Z(0)-Z(2) normal
                  --vz(to_integer(unsigned(cnt_ch))) <= 500; -- [um/s] debug vz for IRI=1 mm/m at 4 g range and 5 cm sampling
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
            case cnt(4 downto 0) is
              -- TODO IRI-20 uses 16 states, it
              -- can be optimized compacting states
              -- same c=abs(vz(n)) can be used first for IRI-20, then for IRI-100
              -- -------------------- IRI-20 LEFT
              when '0'&x"0" =>
                ib <= irs_tail2 & '0';
                c <= abs(vz(0));
              when '0'&x"2" =>
                -- running sum, subtract tail
                srvz2(0) <= srvz2(0)+c-rb; -- normal
              -- -------------------- IRI-20 RIGHT
              when '0'&x"6" =>
                ib <= irs_tail2 & '1';
                c <= abs(vz(1));
              when '0'&x"8" =>
                -- running sum, subtract tail
                srvz2(1) <= srvz2(1)+c-rb; -- normal
              -- -------------------- IRI-100 LEFT
              when '1'&x"0" =>
                ib <= irs_tail & '0';
                rvz(0) <= abs(vz(0));
                c <= abs(vz(0)); -- data to store
              when '1'&x"2" =>
                -- running sum, subtract tail
                srvz(0) <= srvz(0)+c-rb; -- normal
              --when '1'&x"3" =>
              --  ib <= irs_head & '0'; -- address to write (NOTE obsolete because head=tail)
              when '1'&x"4" =>
                matrix_write <= '1';
              when '1'&x"5" =>
                matrix_write <= '0';
              -- -------------------- IRI-100 RIGHT
              when '1'&x"6" =>
                ib <= irs_tail & '1';
                rvz(1) <= abs(vz(1));
                c <= abs(vz(1)); -- data to store
              when '1'&x"8" =>
                -- running sum, subtract tail
                srvz(1) <= srvz(1)+c-rb; -- normal
              --when '1'&x"9" =>
              --  ib <= irs_head & '1'; -- address to write (NOTE obsolete because head=tail)
              when '1'&x"A" =>
                matrix_write <= '1';
              when '1'&x"B" =>
                matrix_write <= '0';
              when '1'&x"F" =>
                -- IRI-100 advance irs_tail which is equal the head
                if irs_tail = irs_max then -- NOTE if head outside of min/max, it will overwrite matrix!
                  irs_tail <= irs_min; -- wraparound
                else
                  irs_tail <= irs_tail + 1; -- advance for the next time
                end if;
                -- IRI-20 advance irs_tail2
                if irs_tail2 = irs_max then
                  irs_tail2 <= irs_min; -- wraparound
                else
                  irs_tail2 <= irs_tail2 + 1; -- advance for the next time
                end if;
                cnt(cnt_bits-2) <= '1'; -- end
              when others =>
            end case;
            cnt(4 downto 0) <= cnt(4 downto 0) + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- output connection
  vz_l <= std_logic_vector(vz(0));
  vz_r <= std_logic_vector(vz(1));
  srvz_l <= std_logic_vector(srvz(0));
  srvz_r <= std_logic_vector(srvz(1));
  srvz2_l <= std_logic_vector(srvz2(0));
  srvz2_r <= std_logic_vector(srvz2(1));
  ready <= '1' when cnt(cnt_bits-1 downto cnt_bits-2) = "11" else '0';

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
