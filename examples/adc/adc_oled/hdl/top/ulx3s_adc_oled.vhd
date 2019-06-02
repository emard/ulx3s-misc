-- (c)EMARD
-- License=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library ecp5u;
use ecp5u.components.all;

entity ulx3s_adc_oled is
  generic
  (
    C_buttons_test: boolean := true
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
  wifi_gpio2: inout std_logic;
  wifi_gpio15: inout std_logic;
  wifi_gpio16: inout std_logic;

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

  adc_csn:  out std_logic;
  adc_mosi: out std_logic;
  adc_miso: in  std_logic;
  adc_sclk: out std_logic;

  -- Flash ROM (SPI0)
  --flash_miso   : in      std_logic;
  --flash_mosi   : out     std_logic;
  --flash_clk    : out     std_logic;
  --flash_csn    : out     std_logic;

  -- SD card (SPI1)
  sd_dat3_csn, sd_cmd_di, sd_dat0_do, sd_dat1_irq, sd_dat2: inout std_logic := 'Z';
  sd_clk: inout std_logic := 'Z';
  sd_cdn, sd_wp: inout std_logic := 'Z'
  );
end;

architecture Behavioral of ulx3s_adc_oled is
  signal clk_100MHz, clk_60MHz, clk_7M5Hz, clk_12MHz: std_logic;
  signal S_reset: std_logic;
  constant C_adc_channels: integer := 4;
  constant C_adc_bits: integer := 12;
  signal S_adc_dv: std_logic;
  signal S_data: std_logic_vector(127 downto 0);
  signal S_enable: std_logic;
begin
  clk_pll: entity work.clk_25M_100M_7M5_12M_60M
  port map
  (
    CLKI   => clk_25mhz,
    CLKOP  => clk_100MHz,
    CLKOS  => clk_7M5Hz,
    CLKOS2 => clk_12MHz,
    CLKOS3 => clk_60MHz
  );

  wifi_en <= '1';
  wifi_gpio0 <= btn(0);
  S_reset <= not btn(0);

  S_enable <= '1'; -- not btn(1); -- btn1 to hold

  -- press buttons to test ADC
  -- for normal use disable this
  G_btn_test: if C_buttons_test generate
    -- each pressed button will apply a logic level '1'
    -- to FPGA pin shared with ADC channel which should
    -- read something from 12'h000 to 12'hFFF with some
    -- conversion noise
    gn(14) <= btn(1) when btn(6) = '1' else 'Z';
    gp(14) <= btn(2) when btn(6) = '1' else 'Z';
    gn(15) <= btn(3) when btn(6) = '1' else 'Z';
    gp(15) <= btn(4) when btn(6) = '1' else 'Z';
    gn(16) <= btn(5) when btn(6) = '1' else 'Z';
    gp(16) <= btn(5) when btn(6) = '1' else 'Z';
    gn(17) <= btn(5) when btn(6) = '1' else 'Z';
    gp(17) <= btn(5) when btn(6) = '1' else 'Z';
  end generate;

  adc_e: entity work.max1112x_reader
  generic map
  (
    C_channels => C_adc_channels,
    C_bits => C_adc_bits
  )
  port map
  (
    clk => clk_60MHz,
    clken => '1',
    spi_csn => adc_csn,
    spi_clk => adc_sclk,
    spi_mosi => adc_mosi,
    spi_miso => adc_miso,
    dv => S_adc_dv,
    data => S_data(C_adc_channels*C_adc_bits-1 downto 0)
  );

  oled_inst: entity oled_hex_decoder
  generic map
  (
    C_data_len => S_data'length
  )
  port map
  (
    clk => clk_12MHz,
    clken => '1',
    data => S_data,
    spi_resn => oled_resn,
    spi_clk => oled_clk,
    spi_csn => oled_csn,
    spi_dc => oled_dc,
    spi_mosi => oled_mosi
  );
end Behavioral;
