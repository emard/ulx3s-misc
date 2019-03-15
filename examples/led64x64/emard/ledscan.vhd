-- (c)EMARD
-- LICENSE=BSD

-- for some info, see here
-- http://www.benadorassociates.com/pz64f6ad8-cz57da853-64-x-64-pixels-p2-5-p3-p4-indoor-full-color-led-display-module-without-using-the-ribbon-cable.html

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

-- driving sequence

-- addrx -2: blank <= 1, addry <= addry + 1
-- addrx -1: blank <= 0, if addry == 0 then bcm_counter <= bcm_counter + 1
-- addrx 0-63: display bits
-- addrx 62: latch <= 1, display takes 1-clock delay to activate latch
-- addrx 63: latch <= 0, remove latch signal but acutally the display will latch now

-- during addrx = 0-63:
-- convert addrx and addry with combinatorial logic to calculate RGB0 and RGB1
-- RGB0 is pixel in upper half, RGB1 is pixel in lower half (32 pixels below)
-- display clock is the same as clk
-- if 8-bit color intensity > reversed bits of bcm_counter then LED=ON else LED=OFF

-- when all 64x64 LEDs are illuminated (WHITE)
-- then from 4V supply it draws 3.3A

-- Each LED can be either ON or OFF,
-- to display 24-bit color, LEDs need to be somehow
-- flickered as fast as possible
-- simple PWM will do visible flickering so we use
-- a sort of BCM (binary coded modulation)
-- using reverse bits of the frame counter
-- Depending on intensity level, BCM will flicker
-- in 1-6 kHz range, too fast to be visible.

entity ledscan is
    generic
    (
        C_bpc: integer := 8; -- bits per RGB channel
        C_bits_x: integer := 6; -- 2^n LEDs is actual panel width
        C_bits_y: integer := 6  -- 2^n LEDs is actual panel height
    );
    port
    (
        clk     : in  std_logic; -- any clock, usually 25 MHz
        -- r0: red upper half, g1: green lower half (32 pixels below)
        r0, g0, b0, r1, g1, b1: in std_logic_vector(C_bpc-1 downto 0); -- RGB pixel inputs 0-upper and 1-lower half
        -- pixel outputs, antiflickered
        rgb0, rgb1: out std_logic_vector(2 downto 0); -- rgb0: upper half, rgb1: lower half
        -- X counter out (high bit set means H-blank, content not displayed)
        -- combinatorial logic from addrx and addry should generate RGB0 (upper half) and RGB1 (lower half)
        addrx       : out std_logic_vector(C_bits_x downto 0); -- x addry it has 1 bit more
        -- following signals output to LED Panel
        addry       : out std_logic_vector(C_bits_y-2 downto 0); -- y addry 0-31, 1 bit less
        -- latch: short pulse '1' transfers data from shift register
        -- to row drivers and illuminates LED rows addry+0 and addry+32 
        latch      : out std_logic;
        -- blank: short pulse '1' turns off illuminated row and
        -- allows switching to the next row of data.
        blank      : out std_logic
    );
end;

architecture bhv of ledscan is
    -- Internal X/Y counters
    signal R_addrx: std_logic_vector(C_bits_x downto 0); -- one bit more to have small H-blank area
    signal R_addry: std_logic_vector(C_bits_y-2 downto 0); -- one bit less, iterates over half of display
    signal R_latch, R_blank: std_logic;
    -- signal R_random: std_logic_vector(30 downto 0) := (others => '1'); -- 31-bit random (not used)
    signal R_bcm_counter: std_logic_vector(C_bpc-1 downto 0); -- frame counter for BCM
    signal S_compare_val: std_logic_vector(C_bpc-1 downto 0); -- output modulation comapersion value
    constant C_2pixels_b4_1st_x_pixel: std_logic_vector(C_bits_x downto 0) := std_logic_vector(to_unsigned(           -2, C_bits_x+1)); -- -2
    constant C_1pixel_b4_1st_x_pixel:  std_logic_vector(C_bits_x downto 0) := std_logic_vector(to_unsigned(           -1, C_bits_x+1)); -- -1
    constant C_last_x_pixel:           std_logic_vector(C_bits_x downto 0) := std_logic_vector(to_unsigned(2**C_bits_x-1, C_bits_x+1)); -- 2**C_bits_x-1
    constant C_1pixel_b4_last_x_pixel: std_logic_vector(C_bits_x downto 0) := std_logic_vector(to_unsigned(2**C_bits_x-2, C_bits_x+1)); -- 2**C_bits_x-2
begin
    addrx <= R_addrx;
    addry <= R_addry;
    latch <= R_latch;
    blank <= R_blank;

    -- main process that always runs
    process(clk)
    begin
        if rising_edge(clk) then
          if R_addrx = C_last_x_pixel then
            R_addrx <= C_2pixels_b4_1st_x_pixel;
          else
            R_addrx <= R_addrx + 1; -- x counter always runs
          end if;

          case R_addrx is
            when C_2pixels_b4_1st_x_pixel => -- -2
              R_blank <= '1';
              R_addry <= R_addry + 1; -- increment during blank=1
            when C_1pixel_b4_1st_x_pixel => -- -1
              R_blank <= '0';
              if conv_integer(R_addry) = 0 then
                R_bcm_counter <= R_bcm_counter + 1;
              end if;
            when C_1pixel_b4_last_x_pixel => -- 62
              R_latch <= '1'; -- latch request 1-clock early
            when C_last_x_pixel => -- 63
              R_latch <= '0'; -- remove latch request
            when others =>
          end case;
        end if;
    end process;

    -- simple pseudo random number generator, see
    -- https://electronics.stackexchange.com/questions/30521/random-bit-sequence-using-verilog
    -- https://www.xilinx.com/support/documentation/application_notes/xapp052.pdf
    --process(clk)
    --begin
    --  if rising_edge(clk) then
    --    R_random(30 downto 0) <= R_random(29 downto 0) & (R_random(30) xor R_random(27));
    --  end if;
    --end process;
    --S_compare_val <= R_random(C_bpc-1 downto 0);
    -- using RND panel won't flicker as whole, but pixels will have visible noise

    -- https://www.sparkfun.com/sparkx/blog/2650
    -- BCM (binary code modulation) output compare against reversed bits
    -- this works best
    F_reverse_bits:
    for i in 0 to C_bpc-1 generate
      S_compare_val(i) <= R_bcm_counter(C_bpc-1-i);
    end generate;
    --S_compare_val <= R_bcm_counter; -- trust me, this will flicker :)

    -- antiflickered modulated outputs generated by arithmetic comparison against S_compare_val
    rgb0(0) <= '1' when conv_integer(S_compare_val) < conv_integer(r0) else '0';
    rgb0(1) <= '1' when conv_integer(S_compare_val) < conv_integer(g0) else '0';
    rgb0(2) <= '1' when conv_integer(S_compare_val) < conv_integer(b0) else '0';
    rgb1(0) <= '1' when conv_integer(S_compare_val) < conv_integer(r1) else '0';
    rgb1(1) <= '1' when conv_integer(S_compare_val) < conv_integer(g1) else '0';
    rgb1(2) <= '1' when conv_integer(S_compare_val) < conv_integer(b1) else '0';
    
end bhv;
