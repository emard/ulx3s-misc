--
-- AUTHOR=EMARD
-- LICENSE=BSD
--

-- VHDL Wrapper for clock

LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity clk_25_dvi_in_vhd is
  port
  (
    reset        : in  std_logic;
    phasesel     : in  std_logic_vector(1 downto 0);
    phasedir     : in  std_logic;
    phasestep    : in  std_logic;
    phaseloadreg : in  std_logic;
    clki         : in  std_logic;
    clk_shift0   : out std_logic;
    clk_shift    : out std_logic;
    clk_pixel    : out std_logic;
    clk_sys      : out std_logic;
    locked       : out std_logic
  );
end;

architecture syn of clk_25_dvi_in_vhd is
component clk_25_dvi_in -- verilog name and its parameters
  port
  (
    reset        : in  std_logic;
    phasesel     : in  std_logic_vector(1 downto 0);
    phasedir     : in  std_logic;
    phasestep    : in  std_logic;
    phaseloadreg : in  std_logic;
    clki         : in  std_logic;
    clk_shift0   : out std_logic;
    clk_shift    : out std_logic;
    clk_pixel    : out std_logic;
    clk_sys      : out std_logic;
    locked       : out std_logic
  );
end component;

begin
  clk_25_dvi_in_verilog_inst: clk_25_dvi_in
  port map
  (
    clki         => clki,
    reset        => reset,
    phasesel     => phasesel,
    phasedir     => phasedir,
    phasestep    => phasestep,
    phaseloadreg => phaseloadreg,
    clk_sys      => clk_sys,
    clk_shift    => clk_shift,
    clk_shift0   => clk_shift0,
    clk_pixel    => clk_pixel,
    locked       => locked
  );
end syn;
