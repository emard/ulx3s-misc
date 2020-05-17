-- TODO testing

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_arith.ALL;
use ieee.std_logic_unsigned.ALL;

entity tmds_deserializer is
port
(
  clk_pixel, clk_shift: in std_logic; -- pixel shift clock recovered and in phase with tmds_p(3)
  tmds_p: in std_logic_vector(3 downto 0); -- TMDS serial input 3-clock (unused), 2-red, 1-greeen, 0-blue
  outp_red, outp_green, outp_blue: out std_logic_vector(9 downto 0) -- TMDS parallel output
);
end;

architecture Behavioral of tmds_deserializer is
    -- latch data 1 clk_shift cycle earlier to have output in sync with clk_pixel
    constant C_latch_phase: integer := -1; -- default -1 (positive: later, negative: earlier)
    signal R_shift_c, R_latch_c, R_data_c: std_logic_vector(9 downto 0); -- clock
    signal R_shift_r, R_latch_r, R_data_r: std_logic_vector(9 downto 0); -- red
    signal R_shift_g, R_latch_g, R_data_g: std_logic_vector(9 downto 0); -- green
    signal R_shift_b, R_latch_b, R_data_b: std_logic_vector(9 downto 0); -- blue
    constant C_shift_clock_initial: std_logic_vector(9 downto 0) := "0000011111";
    signal R_clock: std_logic_vector(9 downto 0) := C_shift_clock_initial;
    signal R_shift_clock_in_sync: std_logic := '1';
    signal R_shift_clock_synchronizer: std_logic_vector(7 downto 0) := (others => '0');
    signal R_sync_fail: std_logic_vector(6 downto 0); -- counts sync fails, after too many, reinitialize shift_clock
begin
    -- input shifter with latch
    process(clk_shift)
    begin
      if rising_edge(clk_shift) then
        R_shift_c <= tmds_p(3) & R_shift_c(R_shift_c'high downto 1);
        R_shift_r <= tmds_p(2) & R_shift_r(R_shift_r'high downto 1);
        R_shift_g <= tmds_p(1) & R_shift_g(R_shift_g'high downto 1);
        R_shift_b <= tmds_p(0) & R_shift_b(R_shift_b'high downto 1);
        if R_shift_c(5+C_latch_phase downto 4+C_latch_phase) = C_shift_clock_initial(5 downto 4) then
          R_latch_r <= R_shift_r;
          R_latch_g <= R_shift_g;
          R_latch_b <= R_shift_b;
        end if;
      end if;
    end process;
    
    -------------8<------------------------8<-------------
    G_unused: if false generate
    -- every N off-sync cycles of clk_shift: signal to skip 1 cycle in order to get in sync
    process(clk_shift)
    begin
      if rising_edge(clk_shift) then
        if R_shift_clock_in_sync = '0' then
	  if R_shift_clock_synchronizer(R_shift_clock_synchronizer'high) = '1' then
            R_shift_clock_synchronizer <= (others => '0'); -- single clk_shift pulse
          else
            R_shift_clock_synchronizer <= R_shift_clock_synchronizer + 1;
          end if;
        else
          R_shift_clock_synchronizer <= (others => '0');
	end if;
      end if;
    end process;

    -- recovered clock shifter, skips one cycle if sync failed
    process(clk_shift)
    begin
      if rising_edge(clk_shift) then
        if R_shift_clock_synchronizer(R_shift_clock_synchronizer'high) = '0' then
          R_clock <= R_clock(0) & R_clock(R_clock'high downto 1);
        else
          -- synchronization failed, skips one R_clock shift cycle
          -- after too many fails, reinitialize R_clock
          if R_sync_fail(R_sync_fail'high) = '1' then
            R_clock <= C_shift_clock_initial;
            R_sync_fail <= (others => '0');
          else
            R_sync_fail <= R_sync_fail + 1;
          end if;
        end if;
      end if;
    end process;
    end generate; -- G_unused
    -------------8<------------------------8<-------------
    
    -- clk_pixel synchronous output
    process(clk_pixel)
    begin
      if rising_edge(clk_pixel) then
        R_data_r <= R_latch_r;
        R_data_g <= R_latch_g;
        R_data_b <= R_latch_b;
        -- clk_pixel synchronous check: is R_clock in sync with clk_pixel?
        if R_clock(5 downto 4) = C_shift_clock_initial(5 downto 4) then
          R_shift_clock_in_sync <= '1';
        else
          R_shift_clock_in_sync <= '0';
        end if;
      end if;
    end process;

    outp_red <= R_data_r;
    outp_green <= R_data_g;
    outp_blue <= R_data_b;

end Behavioral;
