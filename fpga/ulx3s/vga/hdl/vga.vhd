-- AUTHOR=EMARD
-- LICENSE=BSD
--
-- Generates VGA picture from sequential bitmap data from pixel clock
-- synchronous FIFO.

-- the pixel data in r_i, g_i, b_i registers
-- should be present ahead of time

-- signal 'fetch_next' is set high for 1 clk_pixel
-- period as soon as current pixel data is consumed
-- fifo should be fast enough to fetch new data for
-- new pixel

LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.std_logic_unsigned.all;
--use ieee.std_logic_arith.all;
-- use ieee.math_real.all; -- to calculate log2 bit size

entity vga is
  generic(
    c_resolution_x      : integer := 640;
    c_hsync_front_porch : integer :=  16;
    c_hsync_pulse       : integer :=  96;
    c_hsync_back_porch  : integer :=  44; -- 48
    c_resolution_y      : integer := 480;
    c_vsync_front_porch : integer :=  10;
    c_vsync_pulse       : integer :=   2;
    c_vsync_back_porch  : integer :=  31; -- 33
    c_bits_x            : integer :=  10; -- should fit c_resolution_x + c_hsync_front_porch + c_hsync_pulse + c_hsync_back_porch
    c_bits_y            : integer :=  10; -- should fit c_resolution_y + c_vsync_front_porch + c_vsync_pulse + c_vsync_back_porch
    c_dbl_x             : integer :=   0; -- 0-normal X, 1-double X
    c_dbl_y             : integer :=   0  -- 0-normal X, 1-double X
  );
  port
  (
    clk_pixel: in std_logic;  -- pixel clock, 25 MHz for 640x480
    clk_pixel_ena: in std_logic := '1';  -- pixel clock ena
    test_picture: in std_logic := '0'; -- '1' to show test picture
    fetch_next: out std_logic; -- request FIFO to fetch next pixel data
    beam_x: out std_logic_vector(c_bits_x-1 downto 0);
    beam_y: out std_logic_vector(c_bits_y-1 downto 0);
    r_i, g_i, b_i: in std_logic_vector(7 downto 0) := (others => '0'); -- pixel data from FIFO
    vga_r, vga_g, vga_b: out std_logic_vector(7 downto 0); -- 8-bit VGA video signal out
    vga_hsync, vga_vsync: out std_logic; -- VGA sync
    vga_vblank, vga_blank, vga_de: out std_logic -- V blank for CPU interrupts and H+V blank for digital encoder (HDMI)
  );
end vga;

architecture syn of vga is
    -- function integer ceiling log2
    -- returns how many bits are needed to represent a number of states
    -- example ceil_log2(255) = 8,  ceil_log2(256) = 8, ceil_log2(257) = 9
  --  function ceil_log2(x: integer) return integer is
  --  begin
  --    return integer(ceil((log2(real(x)+1.0E-6))-1.0E-6));
  --  end ceil_log2;

  --constant c_bits_x: integer := 13; -- ceil_log2(c_frame_x-1)
  --constant c_bits_y: integer := 11; -- ceil_log2(c_frame_y-1)
  signal CounterX: unsigned(c_bits_x-1 downto 0); -- (9 downto 0) is good for up to 1023 frame timing width (resolution 640x480)
  signal CounterY: unsigned(c_bits_y-1 downto 0); -- (9 downto 0) is good for up to 1023 frame timing width (resolution 640x480)

  constant c_hblank_on:  unsigned(CounterX'range) := to_unsigned(c_resolution_x - 1, c_bits_x);
  constant c_hsync_on:   unsigned(CounterX'range) := to_unsigned(c_resolution_x + c_hsync_front_porch - 1, c_bits_x);
  constant c_hsync_off:  unsigned(CounterX'range) := to_unsigned(c_resolution_x + c_hsync_front_porch + c_hsync_pulse - 1, c_bits_x);
  constant c_hblank_off: unsigned(CounterX'range) := to_unsigned(c_resolution_x + c_hsync_front_porch + c_hsync_pulse + c_hsync_back_porch - 1, c_bits_x);
  constant c_frame_x:    unsigned(CounterX'range) := to_unsigned(c_resolution_x + c_hsync_front_porch + c_hsync_pulse + c_hsync_back_porch - 1, c_bits_x);
    -- frame_x = 640 + 16 + 96 + 48 = 800;
  constant c_vblank_on:  unsigned(CounterY'range) := to_unsigned(c_resolution_y - 1, c_bits_y);
  constant c_vsync_on:   unsigned(CounterY'range) := to_unsigned(c_resolution_y + c_vsync_front_porch - 1, c_bits_y);
  constant c_vsync_off:  unsigned(CounterY'range) := to_unsigned(c_resolution_y + c_vsync_front_porch + c_vsync_pulse - 1, c_bits_y);
  constant c_vblank_off: unsigned(CounterY'range) := to_unsigned(c_resolution_y + c_vsync_front_porch + c_vsync_pulse + c_vsync_back_porch - 1, c_bits_y);
  constant c_frame_y:    unsigned(CounterY'range) := to_unsigned(c_resolution_y + c_vsync_front_porch + c_vsync_pulse + c_vsync_back_porch - 1, c_bits_y);
    -- frame_y = 480 + 10 + 2 + 33 = 525;
    -- refresh_rate = pixel_clock/(frame_x*frame_y) = 25MHz / (800*525) = 59.52Hz
  signal R_hsync, R_vsync, R_blank, R_disp: std_logic; -- disp = not blank
  signal R_disp_early, R_vdisp: std_logic; -- blank generation
  signal R_blank_early, R_vblank: std_logic; -- blank generation
  signal R_fetch_next: std_logic;
  signal R_vga_r, R_vga_g, R_vga_b: std_logic_vector(7 downto 0);
  -- test picture generation
  signal W, A, T: std_logic_vector(7 downto 0);
  signal Z: std_logic_vector(5 downto 0);
begin
  process(clk_pixel)
  begin
    if rising_edge(clk_pixel) then
    if clk_pixel_ena = '1' then
      if CounterX = c_frame_x then
        CounterX <= (others => '0');
        if CounterY = c_frame_y then
          CounterY <= (others => '0');
        else
          CounterY <= CounterY + 1;
        end if;
      else
        CounterX <= CounterX + 1;
      end if;
      R_fetch_next <= R_disp_early;
    else
      R_fetch_next <= '0';
    end if;
    end if;
  end process;
  
  beam_x <= std_logic_vector(CounterX);
  beam_y <= std_logic_vector(CounterY);

  fetch_next <= R_fetch_next;

  -- generate sync and blank
  process(clk_pixel)
  begin
    if rising_edge(clk_pixel) then
      if CounterX = c_hblank_on then
        R_blank_early <= '1';
        R_disp_early  <= '0';
      elsif CounterX = c_hblank_off then
        R_blank_early <= R_vblank;-- "OR" function
        R_disp_early  <= R_vdisp; -- "AND" function
      end if;
    end if;
  end process;
  process(clk_pixel)
  begin
    if rising_edge(clk_pixel) then
      if CounterX = c_hsync_on then
        R_hsync <= '1';
      elsif CounterX = c_hsync_off then
        R_hsync <= '0';
      end if;
    end if;
  end process;
  process(clk_pixel)
  begin
    if rising_edge(clk_pixel) then
      if CounterY = c_vblank_on then
        R_vblank <= '1';
        R_vdisp  <= '0';
      elsif CounterY = c_vblank_off then
        R_vblank <= '0';
        R_vdisp  <= '1';
      end if;
    end if;
  end process;
  process(clk_pixel)
  begin
    if rising_edge(clk_pixel) then
      if CounterY = c_vsync_on then
        R_vsync <= '1';
      elsif CounterY = c_vsync_off then
        R_vsync <= '0';
      end if;
    end if;
  end process;
  
  -- test picture generator
  A <= (others => '1') when std_logic_vector(CounterX(7 downto 5)) = "010" and std_logic_vector(CounterY(7 downto 5)) = "010" else (others => '0');
  W <= (others => '1') when CounterX(7 downto 0) = CounterY(7 downto 0) else (others => '0');
  Z <= (others => '1') when std_logic_vector(CounterY(4 downto 3)) = not std_logic_vector(CounterX(4 downto 3)) else (others => '0');
  T <= (others => CounterY(6));
  process(clk_pixel)
  begin
    if rising_edge(clk_pixel) then
      if R_blank = '1' then
        -- analog VGA needs this, DVI doesn't
        R_vga_r  <= (others => '0');
        R_vga_g  <= (others => '0');
        R_vga_b  <= (others => '0');
      else
        R_vga_r  <= (((std_logic_vector(CounterX(5 downto 0)) and Z) & "00") or W) and not A;
        R_vga_g  <=  ((std_logic_vector(CounterX(7 downto 0)) and T) or W) and not A;
        R_vga_b  <=    std_logic_vector(CounterY(7 downto 0)) or W or A;
      end if;
      R_blank <= R_blank_early;
      R_disp  <= R_disp_early;
    end if;
  end process;  
  
  vga_r      <= R_vga_r;
  vga_g      <= R_vga_g;
  vga_b      <= R_vga_b;
  vga_hsync  <= R_hsync;
  vga_vsync  <= R_vsync;
  vga_blank  <= R_blank;
  vga_vblank <= R_vblank;
  vga_de     <= R_disp;

end syn;
