library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity spi_osd is
  generic
  (
    c_addr_enable  : std_logic_vector(7 downto 0) := x"FE"; -- high addr byte of enable byte
    c_addr_display : std_logic_vector(7 downto 0) := x"FD"; -- high addr byte of display data, +0x10000 for inverted
    c_start_x      : natural := 64; -- x1  pixel window h-position
    c_start_y      : natural := 48; -- x1  pixel window v-position
    c_char_bits_x  : natural :=  6; -- chars H-size 2**n (x8 pixels)
    c_chars_y      : natural := 20; -- chars V-size (x16 pixels)
    c_bits_x       : natural := 10; -- bits in X counter
    c_bits_y       : natural := 10; -- bits in Y counter
    c_init_on      : natural :=  1; -- 0:default OFF 1:default ON
    c_inverse      : natural :=  1; -- 0:no inverse, 1:inverse chars support
    c_transparency : natural :=  1; -- 1:see-thru OSD menu 0:opaque
    c_bgcolor      : std_logic_vector(23 downto 0) := x"503020"; -- RRGGBB menu background color
    c_char_file    : string  := "osd.mem"; -- initial window content, 2 ASCII HEX digits per line
    c_font_file    : string  := "font_bizcat8x16.mem"; -- font bitmap, 8 ASCII BIN digits per line
    c_sclk_capable_pin : natural := 0
  );
  port
  (
    clk_pixel, clk_pixel_ena : in    std_logic;
    i_r, i_g, i_b            : in    std_logic_vector(7 downto 0);
    i_hsync, i_vsync, i_blank: in    std_logic;
    i_csn, i_sclk, i_mosi    : in    std_logic;
    --o_miso                   : inout std_logic; -- simplicity, not needed
    o_r, o_g, o_b            : out   std_logic_vector(7 downto 0);
    o_hsync, o_vsync, o_blank: out   std_logic
  );
end;

architecture syn of spi_osd is
  component spi_osd_v -- verilog name and its parameters
  generic
  (
    c_addr_enable  : std_logic_vector(7 downto 0);
    c_addr_display : std_logic_vector(7 downto 0);
    c_start_x      : natural;
    c_start_y      : natural;
    c_char_bits_x  : natural;
    c_chars_y      : natural;
    c_bits_x       : natural;
    c_bits_y       : natural;
    c_init_on      : natural;
    c_inverse      : natural;
    c_transparency : natural;
    c_bgcolor      : std_logic_vector(23 downto 0);
    c_char_file    : string;
    c_font_file    : string;
    c_sclk_capable_pin : natural
  );
  port
  (
    clk_pixel, clk_pixel_ena : in    std_logic;
    i_r, i_g, i_b            : in    std_logic_vector(7 downto 0);
    i_hsync, i_vsync, i_blank: in    std_logic;
    i_csn, i_sclk, i_mosi    : in    std_logic;
    --o_miso                   : inout std_logic;
    o_r, o_g, o_b            : out   std_logic_vector(7 downto 0);
    o_hsync, o_vsync, o_blank: out   std_logic
  );
  end component;

begin
  spi_osd_v_inst: spi_osd_v
  generic map
  (
    c_addr_enable  => c_addr_enable,
    c_addr_display => c_addr_display,
    c_start_x      => c_start_x,
    c_start_y      => c_start_y,
    c_char_bits_x  => c_char_bits_x,
    c_chars_y      => c_chars_y,
    c_bits_x       => c_bits_x,
    c_bits_y       => c_bits_y,
    c_init_on      => c_init_on,
    c_inverse      => c_inverse,
    c_transparency => c_transparency,
    c_bgcolor      => c_bgcolor,
    c_char_file    => c_char_file,
    c_font_file    => c_font_file,
    c_sclk_capable_pin => c_sclk_capable_pin
  )
  port map
  (
    clk_pixel => clk_pixel, clk_pixel_ena => clk_pixel_ena,
    i_r => i_r, i_g => i_g, i_b => i_b,
    i_hsync => i_hsync, i_vsync => i_vsync, i_blank => i_blank,
    i_csn => i_csn, i_sclk => i_sclk, i_mosi => i_mosi,
    -- o_miso => o_miso,
    o_r => o_r, o_g => o_g, o_b => o_b,
    o_hsync => o_hsync, o_vsync => o_vsync, o_blank => o_blank
  );
end syn;
