-- (c)EMARD
-- License=BSD

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity top_clkgen is
  generic
  (
    bits: integer := 27
  );
  port
  (
    clk_25mhz : in  std_logic;  -- main clock input from 25MHz clock source
    led       : out std_logic_vector(7 downto 0)
  );
end;

architecture mix of top_clkgen is
    type T_blink is array (0 to 3) of std_logic_vector(bits-1 downto 0);
    signal R_blink: T_blink;
    signal clocks: std_logic_vector(3 downto 0);
begin
    clkgen_inst: entity work.clkgen
    generic map
    (
        in_hz  => natural( 25.0e6),
      out0_hz  => natural(250.0e6),
      out1_hz  => natural(250.0e6),
      out1_deg =>          90,
      out2_hz  => natural(125.0e6),
      out2_deg =>         180,
      out3_hz  => natural( 25.0e6),
      out3_deg =>         270
    )
    port map
    (
      clk_i => clk_25mhz,
      clk_o => clocks
    );

    G_blinks: for i in 0 to 3
    generate
      process(clocks(i))
      begin
        if rising_edge(clocks(i)) then
          R_blink(i) <= R_blink(i)+1;
        end if;
        led(2*i+1 downto 2*i) <= R_blink(i)(bits-1 downto bits-2);
      end process;
    end generate;
    

    -- led <= R_blink(R_blink'high downto R_blink'high-7);
end mix;
