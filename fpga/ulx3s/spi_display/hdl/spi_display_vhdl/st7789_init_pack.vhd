-- (c) EMARD
-- License=BSD

library ieee;
use ieee.std_logic_1164.all;

use work.spi_display_init_pack.all;

-- LCD ST7789 initialization sequence
-- next byte after a NOP command encodes delay in ms

package st7789_init_pack is
  -- all this are commands and should be send with DC line low
  constant C_ST7789_SWRESET: std_logic_vector(7 downto 0) := x"01";
  constant C_ST7789_SLPOUT: std_logic_vector(7 downto 0) := x"11";
  constant C_ST7789_COLMOD: std_logic_vector(7 downto 0) := x"3A";
  constant C_ST7789_MADCTL: std_logic_vector(7 downto 0) := x"36";
  constant C_ST7789_CASET_X: std_logic_vector(7 downto 0) := x"2A";
  constant C_ST7789_RASET_Y: std_logic_vector(7 downto 0) := x"2B";
  constant C_ST7789_INVON: std_logic_vector(7 downto 0) := x"13";
  constant C_ST7789_DISPON: std_logic_vector(7 downto 0) := x"29";
  constant C_ST7789_RAMWR: std_logic_vector(7 downto 0) := x"2C";

  constant C_st7789_init_seq: T_spi_display_init_seq :=
  (
-- after reset, delay 2^17 us = 131ms before sending commands
x"80", x"11",
-- SWRESET, 0-param, delay 2^14 us = 16ms
--x"01", x"80", x"0E",
-- SLPOUT, 0-param, delay 2^17 us = 131ms
x"11", x"80", x"11",
-- DISPOFF, 0-param, delay 2^14 us = 16ms
--x"28", x"80", x"0E",
-- COLMOD, 1-param, 16-bit color, delay 2^14 us = 16ms
x"3A", x"81",  x"55",  x"0E",
-- MADCTL, 1-param
x"36", x"01",  x"C0",
-- CASET X, 4-param start MSB,LSB, end MSB,LSB
x"2A", x"04",  x"00", x"00",  x"00", x"EF",
-- RASET Y, 4-param start MSB,LSB, end MSB,LSB
x"2B", x"04",  x"00", x"50",  x"01", x"3F",
-- INVON, 0-param, delay 2^14 us = 16ms
x"21", x"80", x"0E",
-- NORON, 0-param, delay 2^14 us = 16ms
x"13", x"80", x"0E",
-- DISPON, 0-param, delay 2^14 us = 16ms
x"29", x"80", x"0E",
-- RAMWR 2C 00
x"2C", x"00"
  );
end;
