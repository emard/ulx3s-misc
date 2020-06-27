-- (c)EMARD
-- License=BSD

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library custom_lib;
use custom_lib.blinkpkg.all;

entity blink is
  generic
  (
    bits : natural := c_blink_bits
  );
  port
  (
    clk  : in  std_logic;
    led  : out std_logic_vector(7 downto 0)
  );
end;

architecture mix of blink is
  signal R_counter : unsigned(bits-1 downto 0);
begin
  process(clk)
  begin
    if rising_edge(clk) then
      R_counter <= R_counter+1;
    end if;
  end process;
  led <= std_logic_vector(R_counter(led'range));
end mix;
