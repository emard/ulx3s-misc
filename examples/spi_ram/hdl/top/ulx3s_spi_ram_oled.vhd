-- (c)EMARD
-- License=BSD

-- module to bypass user input and usbserial to esp32 wifi

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--library ecp5u;
--use ecp5u.components.all;

entity ulx3s_spi_ram_oled is
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
  ftdi_ndsr: inout  std_logic;
  ftdi_nrts: inout  std_logic;
  ftdi_txden: inout std_logic;

  -- UART1 (WiFi serial)
  wifi_rxd: out   std_logic;
  wifi_txd: in    std_logic;
  -- WiFi additional signaling
  wifi_en: inout  std_logic := 'Z'; -- '0' will disable wifi by default
  wifi_gpio0: inout std_logic;
  wifi_gpio5: inout std_logic;
  wifi_gpio16: inout std_logic;
  wifi_gpio17: inout std_logic;

  -- Onboard blinky
  led: out std_logic_vector(7 downto 0);
  btn: in std_logic_vector(6 downto 0);
  sw: in std_logic_vector(1 to 4);
  oled_csn, oled_clk, oled_mosi, oled_dc, oled_resn: out std_logic;

  -- GPIO (some are shared with wifi and adc)
  gp, gn: inout std_logic_vector(27 downto 0) := (others => 'Z');
  
  -- FPGA direct USB connector
  usb_fpga_dp, usb_fpga_dn: inout std_logic;

  -- SHUTDOWN: logic '1' here will shutdown power on PCB >= v1.7.5
  shutdown: out std_logic := '0';

  -- Digital Video (differential outputs)
  --gpdi_dp, gpdi_dn: out std_logic_vector(2 downto 0);
  --gpdi_clkp, gpdi_clkn: out std_logic;

  -- Flash ROM (SPI0)
  --flash_miso   : in      std_logic;
  --flash_mosi   : out     std_logic;
  --flash_clk    : out     std_logic;
  --flash_csn    : out     std_logic;

  -- SD card (SPI1)
  sd_d: inout std_logic_vector(3 downto 0) := (others => 'Z');
  sd_clk, sd_cmd: inout std_logic := 'Z';
  sd_cdn, sd_wp: inout std_logic := 'Z'
);
end;

architecture Behavioral of ulx3s_spi_ram_oled is
  signal S_oled: std_logic_vector(63 downto 0);
  signal R_counter: std_logic_vector(1 downto 0);
  signal S_enable: std_logic;
  signal S_oled_clk_en: std_logic; 
  signal S_ram_addr: std_logic_vector(15 downto 0);
  signal S_ram_di, S_ram_do: std_logic_vector(7 downto 0);
  signal R_ram_di: std_logic_vector(7 downto 0);
  signal R_prepare_read: std_logic;
  signal S_ram_we: std_logic;
  signal S_csn: std_logic;
begin
  -- TX/RX passthru
  ftdi_rxd <= wifi_txd;
  wifi_rxd <= ftdi_txd;
  wifi_en <= '1';
  wifi_gpio0 <= btn(0);

  sd_d(3) <= '1'; -- SD SPI disabled
  S_csn <= not wifi_gpio5; -- not wifi LED
  E_spi_ram_slave: entity work.spi_ram_slave
  port map
  (
    clk  => clk_25mhz,

    csn  => S_csn,
    sclk => wifi_gpio16,
    mosi => sd_d(1),  -- wifi_gpio4
    miso => sd_d(2),  -- wifi_gpio12

    ram_addr => S_ram_addr,
    ram_we   => S_ram_we,
    ram_do => S_ram_do,
    ram_di => S_ram_di
  );

  E_bram_true2p_2clk: entity work.bram_true2p_2clk
  generic map
  (
    dual_port  => False,
    data_width => 8,
    addr_width => 16
  )
  port map
  (
    clk_a      => clk_25mhz,
    addr_a     => S_ram_addr,
    we_a       => S_ram_we,
    data_in_a  => S_ram_do,
    data_out_a => S_ram_di,
    clk_b      => '0'
  );

  process(clk_25mhz)
  begin
    if rising_edge(clk_25mhz) then
      if S_ram_we = '0' then
        if S_ram_addr(7 downto 0) = x"00" then -- display RAM addr 0
          R_prepare_read <= '1'; -- prepare to read in next clock
        end if;
        if R_prepare_read = '1' then
          R_ram_di <= S_ram_di;
          R_prepare_read <= '0';
        end if;
      end if;
    end if;
  end process;

  S_oled <= '0' & btn & x"234567" & R_ram_di & S_ram_do & S_ram_addr;
  process(clk_25mhz)
  begin
    if rising_edge(clk_25mhz) then
      R_counter <= R_counter + 1;
    end if;
  end process;
  S_oled_clk_en <= '1' when R_counter = "11" else '0';
  S_enable <= not btn(1); -- btn1 to hold
  oled_inst: entity work.oled_hex_decoder
  generic map
  (
    C_data_len => S_oled'length
  )
  port map
  (
    clk => clk_25mhz,
    clken => S_oled_clk_en,
    en => S_enable,
    data => S_oled,
    spi_resn => oled_resn,
    spi_clk => oled_clk,
    spi_csn => oled_csn,
    spi_dc => oled_dc,
    spi_mosi => oled_mosi
  );
  
  led(0) <= oled_resn;
  led(1) <= oled_csn;
  led(2) <= oled_dc;
  led(3) <= oled_clk;
  led(4) <= oled_mosi;

end Behavioral;
