
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity serialiser_10_to_x is
  Generic 
  (
    c_output_bits : natural := 1
  );
  Port 
  (
    clk    : in  STD_LOGIC;
    clk_x  : in  STD_LOGIC;
    data   : in  STD_LOGIC_VECTOR (9 downto 0);
    reset  : in  STD_LOGIC;
    serial : out STD_LOGIC_VECTOR (c_output_bits-1 downto 0)
  );
end;

architecture Behavioral of serialiser_10_to_x is
    signal R_clk_toggler, R_clk_tracker: std_logic;
    signal R_data_shift: std_logic_vector(9 downto 0);
    constant C_insert0: std_logic_vector(c_output_bits-1 downto 0) := (others => '0');
begin

  process(clk)
  begin
    if rising_edge(clk) then
      R_clk_toggler <= not R_clk_toggler;
    end if;
  end process;

  process(clk_x)
  begin
    if rising_edge(clk_x) then
      R_clk_tracker <= R_clk_toggler;
      if R_clk_tracker = R_clk_toggler then
        R_data_shift <= C_insert0 & R_data_shift(R_data_shift'high downto c_output_bits);
      else
        R_data_shift <= data;
      end if;
    end if;
  end process;

  serial <= R_data_shift(c_output_bits-1 downto 0);

end Behavioral;
