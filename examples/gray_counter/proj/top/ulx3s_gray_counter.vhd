-- (c)EMARD
-- License=BSD

-- module to bypass user input and usbserial to esp32 wifi

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ulx3s_gray_counter is
  generic
  (
    C_dummy_constant: integer := 0
  );
  port
  (
  clk_25mhz: in std_logic;  -- main clock input from 25MHz clock source

  -- UART0 (FTDI USB slave serial)
  ftdi_rxd: out   std_logic;
  ftdi_txd: in    std_logic;
  -- FTDI additional signaling
  ftdi_ndtr: inout  std_logic;
  ftdi_nrts: inout  std_logic;
  ftdi_txden: inout std_logic;

  -- UART1 (WiFi serial)
  wifi_rxd: out   std_logic;
  wifi_txd: in    std_logic;
  -- WiFi additional signaling
  wifi_en: inout  std_logic := 'Z'; -- '0' will disable wifi by default
  wifi_gpio0: inout std_logic;
  wifi_gpio2: inout std_logic;
  wifi_gpio15: inout std_logic;
  wifi_gpio16: inout std_logic;

  -- Onboard blinky
  led: out std_logic_vector(7 downto 0);
  btn: in std_logic_vector(6 downto 0);
  sw: in std_logic_vector(1 to 4);
  oled_csn, oled_clk, oled_mosi, oled_dc, oled_resn: out std_logic;

  -- GPIO (some are shared with wifi and adc)
  gp, gn: inout std_logic_vector(27 downto 0) := (others => 'Z')

  -- SHUTDOWN: logic '1' here will shutdown power on PCB >= v1.7.5
  --shutdown: out std_logic := '0'
  );
end;

architecture Behavioral of ulx3s_gray_counter is
  signal S_enable: std_logic;
  signal R_counter: std_logic_vector(23 downto 0);
begin

  -- TX/RX passthru
  ftdi_rxd <= wifi_txd;
  wifi_rxd <= ftdi_txd;

  wifi_en <= '1';
  wifi_gpio0 <= btn(0);

  process(clk_25mhz)
  begin
    if rising_edge(clk_25mhz) then
      if R_counter(R_counter'high)='1' then
        R_counter <= (others => '0');
      else
        R_counter <= R_counter + 1;
      end if;
    end if;
  end process;
  S_enable <= R_counter(R_counter'high);

  gray_inst: entity work.gray_counter
  port map
  (
    clk => clk_25mhz,
    reset => btn(1),
    enable => S_enable,
    gray_count => led
  );

--  led(7) <= R_counter(R_counter'high-1);

end Behavioral;
