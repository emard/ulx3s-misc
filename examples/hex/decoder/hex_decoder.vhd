--
-- AUTHOR=EMARD
-- LICENSE=BSD
--

-- VHDL Wrapper for Verilog

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity hex_decoder is
  generic
  (
    c_data_len   : integer := 64; -- input bits data len
    c_row_bits   : integer := 4;  -- 2^n hex digits: splits data into rows of hex digits 3:8, 4:16, 5:32, 6:64, etc.
    c_grid_6x8   : integer := 0;  -- 0:8x8 grid, 1:6x8 grid NOTE: trellis must use "-abc9" to compile
    c_pipeline   : integer := 1;  -- 0:combinatorial (no clk), 1:pipelined (uses clk)
    c_font_file  : string  := "hex_font.mem";
    c_font_size  : integer := 136;
    c_color_bits : integer := 16; -- 8 or 16 for color screens, 7 monochrome for SSD1306
    c_x_bits     : integer := 7;    -- X screen bits
    c_y_bits     : integer := 7     -- Y screen bits
  );
  port
  (
    clk   : in  std_logic; -- 25-100 MHz clock typical
    data  : in  std_logic_vector(c_data_len-1 downto 0);
    x     : in  std_logic_vector(c_x_bits-1 downto 0);
    y     : in  std_logic_vector(c_y_bits-1 downto 0);
    color : out std_logic_vector(c_color_bits-1 downto 0)
  );
end;

architecture syn of hex_decoder is
  component hex_decoder_v -- verilog name and its parameters
  generic
  (
    c_data_len   : integer := 64; -- input bits data len
    c_row_bits   : integer := 4;  -- 2^n hex digits: splits data into rows of hex digits 3:8, 4:16, 5:32, 6:64, etc.
    c_grid_6x8   : integer := 0;  -- 0:8x8 grid, 1:6x8 grid NOTE: trellis must use "-abc9" to compile
    c_pipeline   : integer := 1;  -- 0:combinatorial (no clk), 1:pipelined (uses clk)
    c_font_file  : string  := "hex_font.mem";
    c_font_size  : integer := 136;
    c_color_bits : integer := 16; -- 8 or 16 for color screens, 7 monochrome for SSD1306
    c_x_bits     : integer := 7;    -- X screen bits
    c_y_bits     : integer := 7     -- Y screen bits
  );
  port
  (
    clk   : in  std_logic; -- 25-100 MHz clock typical
    data  : in  std_logic_vector(c_data_len-1 downto 0);
    x     : in  std_logic_vector(c_x_bits-1 downto 0);
    y     : in  std_logic_vector(c_y_bits-1 downto 0);
    color : out std_logic_vector(c_color_bits-1 downto 0)
  );
  end component;
begin
  hex_decoder_inst: hex_decoder_v
  generic map
  (
    c_data_len   => c_data_len,
    c_row_bits   => c_row_bits,
    c_grid_6x8   => c_grid_6x8,
    c_pipeline   => c_pipeline,
    c_font_file  => c_font_file,
    c_font_size  => c_font_size,
    c_color_bits => c_color_bits,
    c_x_bits     => c_x_bits,
    c_y_bits     => c_y_bits
  )
  port map
  (
    clk   => clk,
    data  => data,
    x     => x,
    y     => y,
    color => color
  );
end syn;
