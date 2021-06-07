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

-- green tab displays have strange power on default
-- workaround is one dummy initialization first
-- and then real initialization

-- dummy initialization
-- SWRESET, delay 2^14 us = 16ms
x"01", x"80", x"0E",
-- SLPOUT, delay 2^14 us = 16ms
x"11", x"80", x"0E",
-- DISPOFF, delay 2^14 us = 16ms
x"28", x"80", x"0E",
-- COLMOD, 16-bit color, delay 2^14 us = 16ms
x"3A", x"81",  x"55",  x"0E",
-- MADCTL
x"36", x"01",  x"C0",
-- CASET X, start MSB,LSB, end MSB,LSB
x"2A", x"04",  x"00", x"00",  x"00", x"EF",
-- RASET Y, start MSB,LSB, end MSB,LSB
x"2B", x"04",  x"00", x"00",  x"00", x"EF",
-- INVON, delay 2^14 us = 16ms
x"21", x"80", x"0E",
-- NORON, delay 2^14 us = 16ms
x"13", x"80", x"0E",
-- DISPON, delay 2^14 us = 16ms
x"29", x"80", x"0E",

-- real initialization
-- SWRESET, delay 2^17 us = 131ms
x"01", x"80", x"11",
-- SLPOUT, delay 2^14 us = 16ms
x"11", x"80", x"0E",
-- DISPOFF, delay 2^14 us = 16ms
x"28", x"80", x"0E",
-- MADCTL
x"36", x"01",  x"C0",
-- COLMOD, 16-bit color, delay 2^14 us = 16ms
x"3A", x"81",  x"55",  x"0E",
-- PORCH SETTING, (frame rate) 5-param, delay 2^14 us = 16ms
x"B2", x"85",  x"0C", x"0C", x"00", x"33", x"33",  x"0E",
-- GATE CONTROL, 1-param
x"B7", x"01",  x"35",
-- VCOM SETTING
x"BB", x"01",  x"2B",
x"C0", x"01",  x"2C",
x"C2", x"02",  x"01", x"FF",
x"C3", x"01",  x"11",
x"C4", x"01",  x"20",
x"C6", x"01",  x"0F",
x"D0", x"02",  x"A4", x"A1",
-- CASET X, start MSB,LSB, end MSB,LSB
x"2A", x"04",  x"00", x"00",  x"00", x"EF",
-- RASET Y, start MSB,LSB, end MSB,LSB
x"2B", x"04",  x"00", x"50",  x"01", x"3F",
-- INVON, delay 2^14 us = 16ms
x"21", x"80", x"0E",
-- NORON, delay 2^14 us = 16ms
x"13", x"80", x"0E",
-- DISPON, delay 2^14 us = 16ms
x"29", x"80", x"0E",
-- RAMWR 2C 00
x"2C", x"00"
  );
end;
