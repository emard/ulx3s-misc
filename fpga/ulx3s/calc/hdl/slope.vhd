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
  g_initial: integer := 0; -- slope DC removal accel compensation at power up
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
  signal sl, sr, sl_next, sr_next : signed(31+scale downto 0); -- sum of const/vz, 42 bits (last 10 bits dropped at output)
  signal sl_prev, sr_prev, dsl, dsr : signed(31+scale downto 0); -- previous slope for derivative
  signal iazl, iazr : signed(15 downto 0); -- z-acceleration, DC removed
  signal gzl, gzr : signed(15 downto 0) := to_signed(g_initial,16); -- g used to remove slope DC offset
  constant avg_bits: integer := 8; -- bits to collect az sum to average
  signal avg_n: unsigned(avg_bits-1 downto 0); -- counter
  signal sgzl, sgzr : signed(15+avg_n'length downto 0); -- sum to average g used to remove slope DC offset
  constant sg0: signed := to_signed(0,sgzl'length); -- 0 for reset sum
  signal agzl, agzr : signed(15 downto 0) := to_signed(g_initial,16); -- average g used to remove slope DC offset
  constant cntadj_bits: integer := 1; -- every 2**n next_interval control slope DC offset
  -- cndatj_bits too small: compensation fast but increase iri too much
  -- cntadj_bits too large: comensation too slow, less iri increase
  -- check iri when sensor is idle and at lowest practical speeds 10 or 20 km/h
  signal cntadj: unsigned(cntadj_bits-1 downto 0); -- counter
  signal control_now: std_logic := '0'; -- control enable
  signal next_interval : std_logic; -- every 25cm x-interval
  constant interval_x : unsigned(31 downto 0) := to_unsigned(1000*interval_mm,32); -- interval um
  signal icvx2: signed(31 downto 0); -- constant/vx
  signal avz2l, avz2r: signed(icvx2'length+iazl'length-1 downto 0); -- multiplier result 48-bit
  --constant negative_not_too_large: signed(avz2l'length-1 downto scale+10) := (others => '1');
  --constant positive_not_too_large: signed(avz2l'length-1 downto scale+10) := (others => '0');
begin
  ivx <= unsigned(vx); -- same value, vhdl type conversion

  -- sum to average gz
  process(clk)
  begin
    if rising_edge(clk) then
      if enter = '1' then
        if avg_n = to_unsigned(0,avg_n'length) then
          -- averaged values, shift-divided by N
          agzl <= sgzl(15+avg_n'length downto avg_n'length);
          agzr <= sgzr(15+avg_n'length downto avg_n'length);
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
            --if avz2l(avz2l'high) = '1' then -- avz2l < 0 (sl derivative)
            if dsl(dsl'high) = '1' then -- dsl < 0 (sl derivative) slope is falling
            --  gzl <= gzl - 2;
            --else -- avz2l >= 0
              gzl <= gzl - 1;
            end if;
          else -- sl >= 0
            -- if avz2l(avz2l'high) = '0' then -- avz2l >= 0 (sl derivative)
            if dsl(dsl'high) = '0' then -- dsl >= 0 (sl derivative) slope is rising
            --  gzl <= gzl + 2;
            --else -- avz2l < 0
              gzl <= gzl + 1;
            end if;
          end if;
          if sr(sr'high) = '1' then -- sr < 0
            --if avz2r(avz2r'high) = '1' then -- avz2r < 0 (sr derivative)
            if dsr(dsr'high) = '1' then -- dsr < 0 (sl derivative) slope is falling
            --  gzr <= gzr - 2;
            --else -- avz2r >= 0
              gzr <= gzr - 1;
            end if;
          else -- sr >= 0
            --if avz2r(avz2r'high) = '0' then -- avz2r >= 0 (sr derivative)
            if dsr(dsr'high) = '0' then -- dsr >= 0 (sl derivative) slope is rising
            --  gzr <= gzr + 2;
            --else -- avz2r < 0
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
      iazl <= signed(azl) - gzl;
      iazr <= signed(azr) - gzr;
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

  slope_l <= std_logic_vector(sl(31+scale downto scale));
  slope_r <= std_logic_vector(sr(31+scale downto scale));
  ready <= next_interval;
  
  d0 <= std_logic_vector(agzl) & std_logic_vector(agzr);
  d1 <= std_logic_vector(azl) & std_logic_vector(azr);
end;
