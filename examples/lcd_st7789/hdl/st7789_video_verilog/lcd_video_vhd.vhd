-- VHDL wrapper for lcd_video

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity lcd_video_vhd is
  generic
  (
    c_clk_mhz           : natural := 25;
    c_reset_us          : natural := 150000;
    c_color_bits        : natural := 16;
    c_vga_sync          : natural := 0;
    c_x_size            : natural := 240;
    c_y_size            : natural := 240;
    c_x_bits            : natural := 8; -- 240->8 ceil(log(c_x_size)/log(2))
    c_y_bits            : natural := 8; -- 240->8 ceil(log(c_y_size)/log(2))
    c_clk_phase         : natural := 0;
    c_clk_polarity      : natural := 1;
    c_init_file         : string  := "st7789_init.mem";
    c_init_size         : natural := 38; -- bytes in init file
    c_nop               : std_logic_vector(7 downto 0) := x"00"
  );
  port
  (
    clk                 : in  std_logic; -- SPI display clock rate will be half of this clock rate
    reset               : in  std_logic;
    clk_pixel_ena       : in  std_logic := '1';
    hsync, vsync, blank : in  std_logic;
    color               : in  std_logic_vector(c_color_bits-1 downto 0);
    
    x                   : out std_logic_vector(c_x_bits-1 downto 0);
    y                   : out std_logic_vector(c_y_bits-1 downto 0);

    next_pixel          : out std_logic; -- 1 when x/y changes

    spi_csn             : out std_logic;
    spi_clk             : out std_logic;
    spi_mosi            : out std_logic;
    spi_dc              : out std_logic;
    spi_resn            : out std_logic
  );
end;

architecture syn of lcd_video_vhd is
  component lcd_video -- verilog name and its parameters
  generic
  (
    c_clk_mhz           : natural := 25;
    c_reset_us          : natural := 150000;
    c_color_bits        : natural := 16;
    c_vga_sync          : natural := 0;
    c_x_size            : natural := 240;
    c_y_size            : natural := 240;
    c_x_bits            : natural := 8; -- 240->8 ceil(log(c_x_size)/log(2))
    c_y_bits            : natural := 8; -- 240->8 ceil(log(c_y_size)/log(2))
    c_clk_phase         : natural := 0;
    c_clk_polarity      : natural := 1;
    c_init_file         : string  := "st7789_init.mem";
    c_init_size         : natural := 38; -- bytes in init file
    c_nop               : std_logic_vector(7 downto 0) := x"00"
  );
  port
  (
    clk                 : in  std_logic; -- SPI display clock rate will be half of this clock rate
    reset               : in  std_logic;
    clk_pixel_ena       : in  std_logic := 1;
    hsync, vsync, blank : in  std_logic;
    color               : in  std_logic_vector(c_color_bits-1 downto 0);
    
    x                   : out std_logic_vector(c_x_bits-1 downto 0);
    y                   : out std_logic_vector(c_y_bits-1 downto 0);

    next_pixel          : out std_logic; -- 1 when x/y changes

    spi_csn             : out std_logic;
    spi_clk             : out std_logic;
    spi_mosi            : out std_logic;
    spi_dc              : out std_logic;
    spi_resn            : out std_logic
  );
  end component;

begin
  lcd_video_inst: lcd_video
  generic map
  (
    c_clk_mhz           => c_clk_mhz,
    c_reset_us          => c_reset_us,
    c_color_bits        => c_color_bits,
    c_vga_sync          => c_vga_sync,
    c_x_size            => c_x_size,
    c_y_size            => c_y_size,
    c_x_bits            => c_x_bits,
    c_y_bits            => c_y_bits,
    c_clk_phase         => c_clk_phase,
    c_clk_polarity      => c_clk_polarity,
    c_init_file         => c_init_file,
    c_init_size         => c_init_size,
    c_nop               => c_nop
  )
  port map
  (
    clk                 => clk,
    reset               => reset,
    clk_pixel_ena       => clk_pixel_ena,
    hsync               => hsync,
    vsync               => vsync, 
    blank               => blank,
    color               => color,

    x                   => x,
    y                   => y,

    next_pixel          => next_pixel,

    spi_csn             => spi_csn,
    spi_clk             => spi_clk,
    spi_mosi            => spi_mosi,
    spi_dc              => spi_dc,
    spi_resn            => spi_resn
  );
end syn;
