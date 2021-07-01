-- response calculator
-- (c) Davor Jadrijevic
-- LICENSE=BSD

-- from acceleration and speed calculate slope
-- calculate slope at every interval_mm

-- slope should not build up much DC
-- so feedback loop that adjusts acceleration +-1
-- each step
-- TODO better (faster) DC removal

library ieee;
use ieee.std_logic_1164.all;
-- use ieee.std_logic_arith.all; -- replaced by ieee.numeric_std.all
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use work.coefficients.all; -- coefficients matrix

entity slope is
generic (
  int_sample_rate_hz: integer := 1000; -- Hz accel input sample rate
  -- 1024 to provide enough resolution for high speeds > 20 m/s
  -- 1.0e6 to scale resulting slope to um/s
  -- 9.81 = 1g standard gravity
  -- 16384 sensor reading for 1g
  -- 0.25 interval in m
  -- 1024*1.0e6*9.81/16384/0.25 = 2452500
  int_vx2_scale: integer := 2452500 -- not used here, used in ESP32
);
port (
  clk              : in  std_logic;
  reset            : in  std_logic;
  enter            : in  std_logic; -- '1' pulse to enter acceleration and speed for every
  x_inc            : in  std_logic_vector(31 downto 0); -- um travel for each 1kHz sensor signed
  cvx2             : in  std_logic_vector(31 downto 0); -- proportional to int_vx2_scale/vx^2 = 2452500/vx^2 signed
  azl, azr         : in  std_logic_vector(15 downto 0); -- acceleration signed 16384 = 1g
  slope_l, slope_r : out std_logic_vector(31 downto 0); -- um/m slope signed
  ready            : out std_logic; -- '1' pulse when result is ready
  d0, d1, d2, d3   : out std_logic_vector(31 downto 0) -- debug outputs
);
end;

architecture RTL of slope is
  signal ix, ix_next, ix_inc: signed(31 downto 0); -- traveled distance um
  signal sl, sr, sr_next, sl_next : signed(41 downto 0); -- sum of const/vz^2, 42 bits (last 10 bits dropped at output)
  signal avz2l, avz2r: signed(47 downto 0); -- multiplier
  signal iazl, iazr : signed(15 downto 0); -- z-acceleration signed
  signal adifl, adifr : signed(15 downto 0); -- z-acceleration differential adjust
  signal icvx2: signed(31 downto 0);
  signal next_interval : std_logic;
  constant interval_x : signed(31 downto 0) := to_signed(1000*interval_mm,32); -- interval um
begin
  ix_inc <= signed(x_inc);
  process(clk)
  begin
    if rising_edge(clk) then
      if enter = '1' then
      --if next_interval = '1' then
        -- slowly adjust acceleration to prevent slope build up DC
        if sl < 0 then
          if avz2l < 0 then
            adifl <= adifl + 2;
          else
            adifl <= adifl + 1;
          end if;
        else
          if sl > 0 then
            if avz2l > 0 then
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
    end if;
  end process;

  icvx2  <= signed(cvx2);

  -- x_inc should be less tnan interval_x
  ix_next  <= ix + ix_inc;
  sl_next  <= sl + avz2l(41 downto 0);
  sr_next  <= sr + avz2r(41 downto 0);

  process(clk)
  begin
    if rising_edge(clk) then
      avz2l <= iazl * icvx2; -- differential of slope
      avz2r <= iazr * icvx2; -- differential of slope
      if reset = '1' then
        ix <= (others => '0');
        sl <= (others => '0');
        sr <= (others => '0');
      else
        if enter = '1' then
          if ix > interval_x then
            ix <= ix_next - interval_x;
            next_interval <= '1';
          else
            ix <= ix_next;
            next_interval <= '0';
          end if;
          sl <= sl_next;
          sr <= sr_next;
        else
          next_interval <= '0';
        end if;
      end if;
    end if;
  end process;

  slope_l <= std_logic_vector(sl(41 downto 10));
  slope_r <= std_logic_vector(sr(41 downto 10));
  ready <= next_interval;
  
  d0 <= x"0000" & std_logic_vector(adifl);
end;
