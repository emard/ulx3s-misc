-- (c)EMARD
-- License=BSD

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library custom_lib;

entity top_blink is
  generic
  (
    bits: integer := 25
  );
  port
  (
    clk_25mhz : in  std_logic;  -- main clock input from 25MHz clock source
    led       : out std_logic_vector(7 downto 0)
  );
end;

architecture mix of top_blink is
begin

    blink_inst: entity custom_lib.blink
    generic map
    (
      bits => bits
    )
    port map
    (
      clk => clk_25mhz,
      led => led
    );

end mix;
