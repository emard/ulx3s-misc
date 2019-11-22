-- AUTHOR = EMARD
-- LICENSE = BSD

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ecp5u;
use ecp5u.components.all;

--library work;
--use work.std.all;

entity ulx3s_usbeth is
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
  usb_fpga_dp: in std_logic; -- differential or single-ended input
  usb_fpga_dn: in std_logic; -- only for single-ended input
  usb_fpga_bd_dp, usb_fpga_bd_dn: inout std_logic; -- single ended bidirectional
  usb_fpga_pu_dp, usb_fpga_pu_dn: inout std_logic; -- pull up for slave, down for host mode

  -- Digital Video (differential outputs)
  --gpdi_dp, gpdi_dn: out std_logic_vector(2 downto 0);
  --gpdi_clkp, gpdi_clkn: out std_logic;

  -- Flash ROM (SPI0)
  --flash_miso   : in      std_logic;
  --flash_mosi   : out     std_logic;
  --flash_clk    : out     std_logic;
  --flash_csn    : out     std_logic;

  -- SD card (SPI1)
  --sd_dat3_csn, sd_cmd_di, sd_dat0_do, sd_dat1_irq, sd_dat2: inout std_logic := 'Z';
  --sd_clk: inout std_logic := 'Z';
  --sd_cdn, sd_wp: inout std_logic := 'Z'

  -- SHUTDOWN: logic '1' here will shutdown power on PCB >= v1.7.5
  shutdown: out std_logic := '0'
);
end;

architecture beh of ulx3s_usbeth is
  signal clk_48MHz, clk_89MHz: std_logic;
begin
  -- USB-CDC core in ethernet mode, ping debug
  -- usb_serial in network mode will reply to raw nping
  -- ifconfig enx00aabbccddee 192.168.18.254
  -- nping -c 100 --privileged -delay 10ms -q1 --send-eth -e enx00aabbccddee --dest-mac 00:11:22:33:44:AA --data 0011223344556677  192.168.18.1
  -- tcpdump -i enx00aabbccddee -e -XX -n icmp

  -- pulldown 15k for USB HOST mode
  usb_fpga_pu_dp <= '1'; -- D+ pullup for USB1.1 device mode
  usb_fpga_pu_dn <= 'Z'; -- D- no pullup for USB1.1 device mode

  clk_single_pll2: entity work.clk_25_125_25_48_89
  port map
  (
    CLKI        =>  clk_25MHz,
    CLKOP       =>  open, -- 125 MHz
    CLKOS       =>  open, -- 25 MHz
    CLKOS2      =>  clk_48MHz,
    CLKOS3      =>  clk_89MHz -- 89.28 MHz
  );

  usbserial_e : entity work.usbeth_icmp_echo
  generic map
  (
    ethernet => true,
    ping => true
  )
  port map
  (
    clk_usb        => clk_48MHz, -- 48 MHz USB core clock
    -- USB interface
    usb_fpga_dp    => usb_fpga_dp,
    --usb_fpga_dn    => usb_fpga_dn,
    usb_fpga_bd_dp => usb_fpga_bd_dp,
    usb_fpga_bd_dn => usb_fpga_bd_dn,
    -- output data
    clk            => clk_48MHz  -- ETH packet application clock
    --dv   => mii_rxvalid,
    --byte => mii_rxdata
  );
end;
