
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity serialiser_10_to_1 is
    Port ( clk    : in STD_LOGIC;
           clk_x5 : in STD_LOGIC;
           data   : in STD_LOGIC_VECTOR (9 downto 0);
           reset  : in std_logic;
           serial : out STD_LOGIC);
end serialiser_10_to_1;

architecture Behavioral of serialiser_10_to_1 is
    signal shift1 : std_logic := '0';
    signal shift2 : std_logic := '0';
    signal ce_delay : std_logic_vector(7 downto 0) := (others => '0');
    signal reset_delay : std_logic_vector(7 downto 0) := (others => '0');
    signal R_clk_toggler, R_clk_tracker: std_logic;
    signal R_data_shift: std_logic_vector(9 downto 0);
begin

  process(clk)
  begin
    if rising_edge(clk) then
      R_clk_toggler <= not R_clk_toggler;
    end if;
  end process;

  process(clk_x5)
  begin
    if rising_edge(clk_x5) then
      R_clk_tracker <= R_clk_toggler;
      if R_clk_tracker = R_clk_toggler then
        R_data_shift <= '0' & R_data_shift(R_data_shift'high downto 1);
      else
        R_data_shift <= data;
      end if;
    end if;
  end process;
  
  serial <= R_data_shift(0);
  
end Behavioral;
