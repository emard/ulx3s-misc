-- (c)EMARD
-- License=BSD

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity top_clkgen is
  generic
  (
    bits: integer := 24
  );
  port
  (
    clk_25mhz : in  std_logic;  -- main clock input from 25MHz clock source
    led       : out std_logic_vector(7 downto 0)
  );
end;

architecture mix of top_clkgen is
    signal R_blink: std_logic_vector(bits-1 downto 0);
    signal clocks: std_logic_vector(3 downto 0);
    alias  clk: std_logic is clocks(3);
begin
    clkgen_inst: entity work.clkgen
    generic map
    (
        in_hz  =>  25000000,
      out0_hz  => 250000000,
      out1_hz  => 250000000,
      out1_deg =>        90,
      out2_hz  => 125000000,
      out2_deg =>       180,
      out3_hz  =>  25000000,
      out3_deg =>       270
    )
    port map
    (
      clk_i => clk_25mhz,
      clk_o => clocks
    );

    process(clk)
    begin
      if rising_edge(clk) then
        R_blink <= R_blink+1;
      end if;
    end process;
    led <= R_blink(R_blink'high downto R_blink'high-7);
end mix;
