-- slope calculator
-- (c) Davor Jadrijevic
-- LICENSE=BSD

-- From acceleration and speed, calculate slope
-- at every interval_mm

-- Slope should not build up much DC to avoid
-- numeric overflow in the response calculator.
-- Simplified PID loop adjusts acceleration offset
-- +-2 at each interval_mm, generating damped
-- oscillations that lead to DC offset removal.
-- Oscillation amplitude and frequency contribute
-- to about 0.01 mm/m IRI noise which has
-- insignificant impact to the measurement.

library ieee;
use ieee.std_logic_1164.all;
-- use ieee.std_logic_arith.all; -- replaced by ieee.numeric_std.all
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use work.coefficients.all; -- coefficients matrix

entity slope is
generic (
  a_default: integer := 0; -- slope DC removal accel compensation at power up
  -- 16000 measuring 1g at +-2g range
  --  8000 measuring 1g at +-4g range
  --  4000 measuring 1g at +-8g range
  scale: integer := 16; -- 16 bits scale
  int_sample_rate_hz: integer := 1000; -- Hz accel input sample rate
  -- 65536 = 2**scale to provide enough resolution for high speeds > 20 m/s
  -- 1.0e6 to scale resulting slope to um/s
  -- 9.81 = 1g standard gravity
  -- 16000 sensor reading for 1g
  -- 1e-3 delta t (1/1kHz sample_rate)
  -- 65536*1.0e6*1e-3*9.81/16000 = 40181.76 -- used in ESP32, spi_write_speed()
  int_vx2_scale: integer := 40182 -- not used here
);
port (
  clk              : in  std_logic;
  reset            : in  std_logic;
  enter            : in  std_logic; -- '1' pulse to enter acceleration and speed for every
  hold             : in  std_logic; -- hold adjustment correction
  vx               : in  std_logic_vector(15 downto 0); -- mm/s, actually um travel for each 1kHz pulse, unsigned
  cvx2             : in  std_logic_vector(31 downto 0); -- proportional to int_vx2_scale/vx = 40181.76/vx signed
  azl, azr         : in  std_logic_vector(15 downto 0); -- acceleration signed 16000 = 1g at +-2g range
  slope_l, slope_r : out std_logic_vector(31 downto 0); -- um/m slope signed
  ready            : out std_logic; -- '1' pulse when result is ready
  d0, d1, d2, d3   : out std_logic_vector(31 downto 0) -- debug outputs
);
end;

architecture RTL of slope is
  signal ix, ix_next: unsigned(31 downto 0); -- traveled distance um
  signal ivx: unsigned(15 downto 0);
  signal sl, sr, sr_next, sl_next : signed(31+scale downto 0); -- sum of const/vz, 42 bits (last 10 bits dropped at output)
  signal iazl, iazr : signed(15 downto 0); -- z-acceleration signed
  signal adifl, adifr : signed(15 downto 0) := to_signed(-a_default,16); -- z-acceleration differential adjust
  signal cntadj: unsigned(6 downto 0); -- counter how often to adjust slope
  signal next_interval : std_logic;
  constant interval_x : unsigned(31 downto 0) := to_unsigned(1000*interval_mm,32); -- interval um
  signal icvx2: signed(31 downto 0);
  signal avz2l, avz2r: signed(icvx2'length+iazl'length-1 downto 0); -- multiplier result 48-bit
begin
  ivx <= unsigned(vx);
  process(clk)
  begin
    if rising_edge(clk) then
      --if enter = '1' and hold = '0' then
      --if enter = '1' and cntadj = to_unsigned(0,cntadj'length) and hold = '0' then
      if reset = '1' then
        adifl  <= not signed(azl); -- approx -signed(azl)
        adifr  <= not signed(azr); -- approx -signed(azr)
        --cntadj <= (others => '0');
      else
      if next_interval = '1' and cntadj = to_unsigned(0,cntadj'length) and hold = '0' then
        -- slowly adjust acceleration to prevent slope build up DC
        if sl < 0 then
          if avz2l < 0 then -- derivative
            adifl <= adifl + 2;
          else
            adifl <= adifl + 1;
          end if;
        else
          if sl > 0 then
            if avz2l > 0 then -- derivative
              adifl <= adifl - 2;
            else
              adifl <= adifl - 1;
            end if;
          end if;
        end if;
        if sr < 0 then
          if avz2r < 0 then
            adifr <= adifr + 2;
          else
            adifr <= adifr + 1;
          end if;
        else
          if sr > 0 then
            if avz2r > 0 then
              adifr <= adifr - 2;
            else
              adifr <= adifr - 1;
            end if;
          end if;
        end if;
      end if;
      iazl <= adifl + signed(azl);
      iazr <= adifr + signed(azr);
      if next_interval = '1' then
        cntadj <= cntadj + 1;
      end if;
      end if; -- if reset = '1' then .. else
    end if;
  end process;

  icvx2  <= signed(cvx2);

  -- x_inc should be less than interval_x
  ix_next  <= (others => '0') when reset = '1' else ix + ivx;
  sl_next  <= (others => '0') when reset = '1' else sl + avz2l(31+scale downto 0);
  sr_next  <= (others => '0') when reset = '1' else sr + avz2r(31+scale downto 0);

  process(clk)
  begin
    if rising_edge(clk) then
        -- FIXME reset is not working, synth problems
        if enter = '1' or reset = '1' then
          if ix > interval_x then
            ix <= ix_next - interval_x;
            next_interval <= '1';
          else
            ix <= ix_next;
            -- next_interval <= '0'; -- do not reset srvz buffer
            next_interval <= reset; -- persistent reset will zero-fill srvz buffer
          end if;
          sl <= sl_next;
          sr <= sr_next;
        else
          next_interval <= '0';
        end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      avz2l <= iazl * icvx2; -- differential of slope
      avz2r <= iazr * icvx2; -- differential of slope
    end if;
  end process;

  slope_l <= std_logic_vector(sl(31+scale downto scale));
  slope_r <= std_logic_vector(sr(31+scale downto scale));
  ready <= next_interval;
  
  d0 <= x"0000" & std_logic_vector(adifl);
end;
