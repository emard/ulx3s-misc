-- TODO this code is incomplete and untested

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity deserialiser_1_to_10 is
Port
(
           delay_ce    : in  std_logic;
           delay_count : in  std_logic_vector (4 downto 0); -- sub-bit delay
           
           ce          : in  STD_LOGIC;
           clk         : in  std_logic; -- delay refclk 200 MHz
           clk_x1      : in  std_logic; -- pixel clock
           bitslip     : in  std_logic; -- skips one bit
           clk_x5      : in  std_logic; -- 5x pixel clock in DDR mode (or 10x in SDR mode)
           serial      : in  std_logic; -- input serial data
           reset       : in  std_logic;
           data        : out std_logic_vector (9 downto 0) -- output data
);
end deserialiser_1_to_10;

architecture Behavioral of deserialiser_1_to_10 is
    constant C_latch_phase: integer := -2; -- default -2 (positive: later, negative: earlier)
    signal R_shift, R_latch, R_data : std_logic_vector(9 downto 0);
    constant C_shift_clock_initial: std_logic_vector(9 downto 0) := "0000011111";
    signal R_clock : std_logic_vector(9 downto 0) := C_shift_clock_initial;
    signal R_shift_clock_off_sync: std_logic := '0';
    signal R_shift_clock_synchronizer: std_logic_vector(7 downto 0) := (others => '0');
    signal R_sync_fail: std_logic_vector(6 downto 0); -- counts sync fails, after too many, reinitialize shift_clock
begin
    -- TODO implement fine-grained delay using "delay_count"

    process(clk_x5)
    begin
      if rising_edge(clk_x5) then
        if bitslip = '0' then
          R_shift <= serial & R_shift(R_shift'high downto 1);
        end if;
        if R_clock(5+C_latch_phase downto 4+C_latch_phase) = C_shift_clock_initial(5 downto 4) then
          R_latch <= R_shift;
        end if;
      end if;
    end process;

    -- every N cycles of clk_shift: signal to skip 1 cycle in order to get in sync
    process(clk_x5)
    begin
		if rising_edge(clk_x5) then
			if R_shift_clock_off_sync = '1' then
				if R_shift_clock_synchronizer(R_shift_clock_synchronizer'high) = '1' then
					R_shift_clock_synchronizer <= (others => '0');
				else
					R_shift_clock_synchronizer <= R_shift_clock_synchronizer + 1;
				end if;
			else
				R_shift_clock_synchronizer <= (others => '0');
			end if;
		end if;
    end process;

    process(clk_x5)
    begin
	    if rising_edge(clk_x5) then
		if R_shift_clock_synchronizer(R_shift_clock_synchronizer'high) = '0' then
			R_clock <= R_clock(0) & R_clock(R_clock'high downto 1);
		else
			-- synchronization failed.
			-- after too many fails, reinitialize shift_clock
			if R_sync_fail(R_sync_fail'high) = '1' then
				R_clock <= C_shift_clock_initial;
				R_sync_fail <= (others => '0');
			else
				R_sync_fail <= R_sync_fail + 1;
			end if;
		end if;
            end if;
    end process;
    
    process(clk_x1)
    begin
      if rising_edge(clk_x1) then
        R_data <= R_latch;
        if R_clock(5 downto 4) = C_shift_clock_initial(5 downto 4) then
          R_shift_clock_off_sync <= '0';
        else
          R_shift_clock_off_sync <= '1';
        end if;
      end if;
    end process;

    data <= R_data;

end Behavioral;
