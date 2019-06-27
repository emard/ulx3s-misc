---------------------------------------------------------------------------------
-- DE2-35 Top level for Phoenix by Dar (darfpga@aol.fr) (April 2016)
-- http://darfpga.blogspot.fr
--
-- Main features
--  USER02 DIP Switch 1 on/off HDMI-audio
--  USER02 simple buttons input
--  MIST DB9 joystick input (works after pressing M-RES button...)
--  PS2 keyboard input (scancodes received, but decoding doesn't work yet)
--  NO board DDR3 used
--
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.ALL;
use ieee.numeric_std.all;

entity blinky is
port
(
  i_100MHz_P, i_100MHz_N: in std_logic;
  LED: out std_logic_vector(2 downto 0) -- onboard LEDs
);
end;

architecture struct of blinky is
  component clk_d100_100_200_125_25MHz is
  Port (
      clk_100mhz_in_p : in STD_LOGIC;
      clk_100mhz_in_n : in STD_LOGIC;
      clk_100mhz : out STD_LOGIC;
      clk_200mhz : out STD_LOGIC;
      clk_125mhz : out STD_LOGIC;
      clk_25mhz : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
  );
  end component;

  signal clk: std_logic;

  signal reset        : std_logic;
  signal clock_stable : std_logic;

  signal R_counter: std_logic_vector(25 downto 0);
begin
  clk100in_out100_200_125_25: clk_d100_100_200_125_25MHz
  port map
  (
    clk_100mhz_in_p => i_100MHz_P,
    clk_100mhz_in_n => i_100MHz_N,
    reset => '0',
    locked => clock_stable,
    clk_100mhz => open,
    clk_200mhz => open,
    clk_125mhz => open,
    clk_25mhz  => clk
  );

  reset <= not clock_stable;

  process(clk_pixel)
  begin
    if rising_edge(clk_pixel) then
      R_counter <= R_counter + 1;
    end if;
  end process;
  LED(0) <= R_counter(R_counter'high);

end struct;
