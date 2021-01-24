library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity osd_vhd is
  generic
  (
    c_x_start       : natural := 128; -- x1  pixel window h-position
    c_x_stop        : natural := 383; -- x1  pixel window h-position
    c_y_start       : natural := 128; -- x1  pixel window v-position
    c_y_stop        : natural := 383; -- x1  pixel window v-position
    c_x_bits        : natural :=  10; -- bits in x counter
    c_y_bits        : natural :=  10; -- bits in y counter
    c_transparency  : natural :=   0  -- 1:see-thru OSD menu 0:opaque
  );
  port
  (
    clk_pixel, clk_pixel_ena  : in    std_logic;
    i_r, i_g, i_b             : in    std_logic_vector(7 downto 0);
    i_hsync, i_vsync, i_blank : in    std_logic;
    i_osd_en                  : in    std_logic;
    i_osd_r, i_osd_g, i_osd_b : in    std_logic_vector(7 downto 0);
    o_osd_x                   : out   std_logic_vector(c_x_bits-1 downto 0);
    o_osd_y                   : out   std_logic_vector(c_y_bits-1 downto 0);
    o_r, o_g, o_b             : out   std_logic_vector(7 downto 0);
    o_hsync, o_vsync, o_blank : out   std_logic;
    o_osd_en                  : out   std_logic
  );
end;

architecture syn of osd_vhd is
  component osd -- verilog name and its parameters
  generic
  (
    c_x_start       : natural;
    c_x_stop        : natural;
    c_y_start       : natural;
    c_y_stop        : natural;
    c_x_bits        : natural;
    c_y_bits        : natural;
    c_transparency  : natural
  );
  port
  (
    clk_pixel, clk_pixel_ena  : in    std_logic;
    i_r, i_g, i_b             : in    std_logic_vector(7 downto 0);
    i_hsync, i_vsync, i_blank : in    std_logic;
    i_osd_en                  : in    std_logic;
    i_osd_r, i_osd_g, i_osd_b : in    std_logic_vector(7 downto 0);
    o_osd_x                   : out   std_logic_vector(c_x_bits-1 downto 0);
    o_osd_y                   : out   std_logic_vector(c_y_bits-1 downto 0);
    o_r, o_g, o_b             : out   std_logic_vector(7 downto 0);
    o_hsync, o_vsync, o_blank : out   std_logic;
    o_osd_en                  : out   std_logic
  );
  end component;

begin
  spi_osd_v_inst: osd
  generic map
  (
    c_x_start       => c_x_start,
    c_x_stop        => c_x_stop,
    c_y_start       => c_y_start,
    c_y_stop        => c_y_stop,
    c_x_bits        => c_x_bits,
    c_y_bits        => c_y_bits,
    c_transparency  => c_transparency
  )
  port map
  (
    clk_pixel => clk_pixel, clk_pixel_ena => clk_pixel_ena,
    i_r => i_r, i_g => i_g, i_b => i_b,
    i_hsync => i_hsync, i_vsync => i_vsync, i_blank => i_blank,
    i_osd_en => i_osd_en,
    i_osd_r => i_osd_r, i_osd_g => i_osd_g, i_osd_b => i_osd_b,
    o_osd_x => o_osd_x,
    o_osd_y => o_osd_y,
    o_r => o_r, o_g => o_g, o_b => o_b,
    o_hsync => o_hsync, o_vsync => o_vsync, o_blank => o_blank,
    o_osd_en => o_osd_en
  );
end syn;
