-- slope calculator
-- (c) Davor Jadrijevic
-- LICENSE=BSD

-- From acceleration and speed, calculate slope
-- and report it at every interval_mm of x-travel

-- Fpr every accelerometer sample interval dt=1/1000 s
-- current slope is calculated as the sum:
-- slope += az*dt/vx

-- external CPU provides vx and cvx2 = dt/vx scaled
-- to a factor for fixed-point arithmetic

-- Slope should not build up much DC to avoid
-- numeric overflow in the response calculator.
-- Simplified PID loop adjusts acceleration offset
-- at each interval_mm, generating slope oscillations.
-- which leads to IRI noise of about:
-- 0.20 mm/m at 10 km/h
-- 0.10 mm/m at 20 km/h
-- 0.01 mm/m at 80 km/h

library ieee;
use ieee.std_logic_1164.all;
-- use ieee.std_logic_arith.all; -- replaced by ieee.numeric_std.all
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use work.coefficients.all; -- coefficients matrix

entity slope is
generic (
  g_initial: integer := 0; -- slope DC removal accel compensation at power up
  -- 16000 measuring 1g at +-2g range
  --  8000 measuring 1g at +-4g range
  --  4000 measuring 1g at +-8g range
  scale: integer := 16; -- 16 bits scale
  int_sample_rate_hz: integer := 1000; -- Hz accel input sample rate
  slope_reconstruction: integer := 0; -- 0: no reconstruction, use X-axis at +2g range: slope = ax * (1000000/16000) [um/m], 1: Z-axis slope reconstruction
  -- 65536 = 2**scale to provide enough resolution for high speeds > 20 m/s
  -- 1.0e6 to scale resulting slope to um/s
  -- 9.81 = 1g standard gravity
  -- 16000 sensor reading for 1g
  -- 1e-3 delta t (1/1kHz sample_rate)
  -- 1000 for speed in mm/s
  -- 65536*1.0e6*1e-3*9.81/16000*1000 = 40181760 -- used in ESP32, spi_write_speed()
  int_vx2_scale: integer := 40181760 -- not used here
);
port (
  clk              : in  std_logic;
  reset            : in  std_logic;
  enter            : in  std_logic; -- '1' pulse to enter acceleration and speed for every
  hold             : in  std_logic; -- hold adjustment correction
  vx               : in  std_logic_vector(15 downto 0); -- mm/s, actually um travel for each 1kHz pulse, unsigned
  cvx2             : in  std_logic_vector(31 downto 0); -- proportional to int_vx2_scale/vx[mm/s] = 40181760/vx[mm/s] signed
  axl, axr, ayl, ayr, azl, azr : in  std_logic_vector(15 downto 0); -- acceleration signed 16000 = 1g at +-2g range
  slope_l, slope_r : out std_logic_vector(31 downto 0); -- um/m slope signed
  ready            : out std_logic; -- '1' pulse when result is ready
  d0, d1, d2, d3   : out std_logic_vector(31 downto 0) -- debug outputs
);
end;

architecture RTL of slope is
  signal ix, ix_next: unsigned(31 downto 0); -- traveled distance um
  signal ivx: unsigned(15 downto 0);
  signal slx, srx: signed(15 downto 0); -- simple slope from X-axis without Z-reconstruction
  signal saxl, saxr: signed(15 downto 0); -- type converted signed axl,axr
  constant csax2sl: signed(15 downto 0) := to_signed(1000000/16000, 16); -- constant from 1g = 16000 to um/m
  signal eslx, esrx: signed(slx'length+csax2sl'length-1 downto 0); -- full width multiply result
  signal sl, sr, sl_next, sr_next : signed(31+scale downto 0); -- sum of const/vz, 42 bits (last 10 bits dropped at output)
  signal sl_prev, sr_prev, dsl, dsr : signed(31+scale downto 0); -- previous slope for derivative
  signal iazl, iazr : signed(15 downto 0); -- z-acceleration, DC removed
  signal gzl, gzr : signed(15 downto 0) := to_signed(g_initial,16); -- g used to remove slope DC offset
  -- avg_bits = 4 -> <62.5  Hz
  -- avg_bits = 5 -> <31.25 Hz
  constant avg_bits: integer := 4; -- every 2**n measurements sum to average agzl, agzr
  signal avg_n: unsigned(avg_bits-1 downto 0); -- counter
  signal sgzl, sgzr : signed(15+avg_n'length downto 0); -- sum to average g used to remove slope DC offset
  constant sg0: signed := to_signed(0,sgzl'length); -- 0 for reset sum
  signal agzl, agzr : signed(15 downto 0) := to_signed(g_initial,16); -- average g used to remove slope DC offset
  --constant cntadj_bits: integer := 1; -- every 2**n next_interval control slope DC offset
  -- cndatj_bits too small: compensation fast but increase iri too much
  -- cntadj_bits too large: comensation too slow, less iri increase
  -- check iri when sensor is idle and at lowest practical speeds 10 or 20 km/h
  --signal cntadj: unsigned(cntadj_bits-1 downto 0); -- counter
  signal control_now: std_logic := '0'; -- control enable
  signal next_interval : std_logic; -- every 25cm x-interval
  constant interval_x : unsigned(31 downto 0) := to_unsigned(1000*interval_mm,32); -- interval um
  signal icvx2: signed(31 downto 0); -- constant/vx
  signal avz2l, avz2r: signed(icvx2'length+iazl'length-1 downto 0); -- multiplier result 48-bit
  --constant negative_not_too_large: signed(avz2l'length-1 downto scale+10) := (others => '1');
  --constant positive_not_too_large: signed(avz2l'length-1 downto scale+10) := (others => '0');
begin
  ivx <= unsigned(vx); -- same value, vhdl type conversion

  -- TODO if/generate avg_enable
  -- sum to average gz
  process(clk)
  begin
    if rising_edge(clk) then
      if enter = '1' then
        if avg_n = to_unsigned(0,avg_n'length) then
          -- averaged values, shift-divided by N
          agzl <= sgzl(agzl'length+avg_n'length-1 downto avg_n'length);
          agzr <= sgzr(agzr'length+avg_n'length-1 downto avg_n'length);
          -- reset sum, take first element
          sgzl <= sg0 + signed(azl);
          sgzr <= sg0 + signed(azr);
        else
          -- accumulate sum
          sgzl <= sgzl + signed(azl);
          sgzr <= sgzr + signed(azr);
        end if;
        avg_n <= avg_n + 1;
      end if;
    end if;
  end process;

  -- when to control slope DC removal:
  -- run counter and generate control_now enable signal
  process(clk)
  begin
    if rising_edge(clk) then
      --if next_interval = '1' and hold = '0' then
      --  if cntadj = to_unsigned(0,cntadj'length) then
      --    control_now <= '1';
      --  else
      --    control_now <= '0';
      --  end if;
      --  cntadj <= cntadj + 1;
      --else
      --  control_now <= '0';
      --end if;
      control_now <= next_interval and not hold;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        --gzl <= signed(azl); -- use current value
        --gzr <= signed(azr); -- use current value
        gzl <= agzl; -- use average value
        gzr <= agzr; -- use average value
      else
        if control_now = '1' then -- slope DC remove control
          -- when both slope sign and derivative sign are both the same
          -- in the direction that drives slope away from 0 then
          -- slowly adjust acceleration to prevent slope build up DC
          -- too fast adjustment increases iri
          if sl(sl'high) = '1' then -- sl < 0
            if dsl(dsl'high) = '1' then -- dsl < 0 (sl derivative) slope is falling
              gzl <= gzl - 1;
            end if;
          else -- sl >= 0
            if dsl(dsl'high) = '0' then -- dsl >= 0 (sl derivative) slope is rising
              gzl <= gzl + 1;
            end if;
          end if;
          if sr(sr'high) = '1' then -- sr < 0
            if dsr(dsr'high) = '1' then -- dsr < 0 (sl derivative) slope is falling
              gzr <= gzr - 1;
            end if;
          else -- sr >= 0
            if dsr(dsr'high) = '0' then -- dsr >= 0 (sl derivative) slope is rising
              gzr <= gzr + 1;
            end if;
          end if;
        end if;
      end if; -- if reset = '1' then .. else
    end if;
  end process;

  -- subtract g in z-direction (gzl, gzr) from sensors reading
  -- this is not real g but a controlled value close to g
  -- that prevents slope to accumulate large DC offset
  process(clk)
  begin
    if rising_edge(clk) then
      iazl <= signed(azl) - gzl; -- current values
      iazr <= signed(azr) - gzr; -- current values
      --iazl <= agzl - gzl; -- average values (tyre ribs removal)
      --iazr <= agzr - gzr; -- average values (tyre ribs removal)
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if enter = '1' then -- enter=1 means accelerometer input is ready
        saxl <= signed(axl);
        saxr <= signed(axr);
      end if;
    end if;
  end process;

  icvx2  <= signed(cvx2);

  -- x_inc should be less than interval_x
  ix_next  <= ix + ivx;
  sl_next  <= (others => '0') when reset = '1' else sl + avz2l(31+scale downto 0);
  sr_next  <= (others => '0') when reset = '1' else sr + avz2r(31+scale downto 0);

  process(clk)
  begin
    if rising_edge(clk) then
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
      avz2l <= iazl * icvx2;
      avz2r <= iazr * icvx2;
    end if;
  end process;

  -- slove derivative
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        dsl <= (others => '0');
        dsr <= (others => '0');
        sl_prev <= (others => '0');
        sr_prev <= (others => '0');
      else
        if control_now = '1' then
          dsl <= sl - sl_prev;
          dsr <= sr - sr_prev;
          sl_prev <= sl;
          sr_prev <= sr;
        end if;
      end if;
    end if;
  end process;

  g_no_slope_reconstruction:
  if slope_reconstruction = 0 generate
    process(clk)
    begin
      if rising_edge(clk) then
        eslx <= saxl * csax2sl;
        esrx <= saxr * csax2sl;
      end if;
    end process;
    slope_l <= std_logic_vector(eslx);
    slope_r <= std_logic_vector(esrx);
  end generate;

  g_yes_slope_reconstruction:
  if slope_reconstruction = 1 generate
    slope_l <= std_logic_vector(sl(31+scale downto scale));
    slope_r <= std_logic_vector(sr(31+scale downto scale));
  end generate;

  ready <= next_interval;
  
  d0 <= std_logic_vector(agzl) & std_logic_vector(agzr);
  d1 <= std_logic_vector(azl) & std_logic_vector(azr);
end;
