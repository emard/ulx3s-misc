-- (c)EMARD
-- License=BSD

-- module to bypass user input and usbserial to esp32 wifi

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library ecp5u;
use ecp5u.components.all;

-- USB packet generator functions
-- use work.usb_req_gen_func_pack.all;
-- package for decoded structure
-- use work.report_decoded_pack.all;

entity ulx3s_usbtest is
  generic
  (
    C_external_ulpi: boolean := false
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

architecture Behavioral of ulx3s_usbtest is
  signal clk_200MHz, clk_100MHz, clk_89MHz, clk_60MHz, clk_48MHz, clk_12MHz, clk_7M5Hz: std_logic;
  signal clk_usb: std_logic; -- 48 or 60 MHz
  signal S_led: std_logic;
  signal S_usb_rst: std_logic;
  signal R_rst_btn: std_logic;
  signal R_phy_txmode: std_logic;
  signal S_rxd: std_logic;
  signal S_rxdp, S_rxdn: std_logic;
  signal S_txdp, S_txdn, S_txoe: std_logic;
  signal S_hid_report: std_logic_vector(63 downto 0);
  signal S_dsctyp: std_logic_vector(2 downto 0);
  signal S_DATABUS16_8: std_logic;
  signal S_RESET: std_logic;
  signal S_XCVRSELECT: std_logic;
  signal S_TERMSELECT: std_logic;
  signal S_OPMODE: std_logic_vector(1 downto 0);
  signal S_LINESTATE: std_logic_vector(1 downto 0);
  signal S_TXVALID: std_logic;
  signal S_TXREADY: std_logic;
  signal S_RXVALID: std_logic;
  signal S_RXACTIVE: std_logic;
  signal S_RXERROR: std_logic;
  signal S_DATAIN: std_logic_vector(7 downto 0);
  signal S_DATAOUT: std_logic_vector(7 downto 0);
  signal S_BREAK: std_logic;
  signal S_ulpi_data_out_i, S_ulpi_data_in_o: std_logic_vector(7 downto 0);
  signal S_ulpi_dir_i: std_logic;
  -- UTMI debug
  signal S_sync_err, S_bit_stuff_err, S_byte_err: std_logic;
  -- registers for OLED
  signal R_txdp, R_txdn: std_logic;
  signal R_OPMODE: std_logic_vector(1 downto 0);
  signal R_LINESTATE: std_logic_vector(1 downto 0);
  signal R_TXVALID: std_logic;
  signal R_TXREADY: std_logic;
  signal R_RXVALID: std_logic;
  signal R_RXACTIVE: std_logic;
  signal R_RXERROR: std_logic_vector(3 downto 0);
  signal R_DATAIN: std_logic_vector(7 downto 0);
  signal R_DATAOUT: std_logic_vector(7 downto 0);
  -- UTMI debug error counters
  signal R_sync_err, R_bit_stuff_err, R_byte_err: std_logic_vector(3 downto 0);

  component ulpi_wrapper
    --generic (
    --  dummy_x          : integer := 0;  -- 0-normal X, 1-double X
    --  dummy_y          : integer := 0   -- 0-normal X, 1-double X
    --);
    port
    (
      -- ULPI Interface (PHY)
      ulpi_clk60_i: in std_logic;  -- input clock 60 MHz
      ulpi_rst_i: in std_logic;
      ulpi_data_out_i: in std_logic_vector(7 downto 0);
      ulpi_data_in_o: out std_logic_vector(7 downto 0);
      ulpi_dir_i: in std_logic;
      ulpi_nxt_i: in std_logic;
      ulpi_stp_o: out std_logic;
      -- UTMI Interface (SIE)
      utmi_txvalid_i: in std_logic;
      utmi_txready_o: out std_logic;
      utmi_rxvalid_o: out std_logic;
      utmi_rxactive_o: out std_logic;
      utmi_rxerror_o: out std_logic;
      utmi_data_in_o: out std_logic_vector(7 downto 0);
      utmi_data_out_i: in std_logic_vector(7 downto 0);
      utmi_xcvrselect_i: in std_logic_vector(1 downto 0);
      utmi_termselect_i: in std_logic;
      utmi_op_mode_i: in std_logic_vector(1 downto 0);
      utmi_dppulldown_i: in std_logic;
      utmi_dmpulldown_i: in std_logic;
      utmi_linestate_o: out std_logic_vector(1 downto 0)
    );
  end component;
begin
  g_single_pll: if true generate
  clk_single_pll: entity work.clk_25M_100M_7M5_12M_60M
  port map
  (
      CLKI        =>  clk_25MHz,
      CLKOP       =>  clk_100MHz,
      CLKOS       =>  clk_7M5Hz,
      CLKOS2      =>  clk_12MHz,
      CLKOS3      =>  clk_60MHz
  );
  end generate;

  g_single_pll2: if true generate
  clk_single_pll2: entity work.clk_25_125_25_48_89
  port map
  (
      CLKI        =>  clk_25MHz,
      CLKOP       =>  open, -- 125 MHz
      CLKOS       =>  open, -- 25 MHz
      CLKOS2      =>  clk_48MHz,
      CLKOS3      =>  clk_89MHz -- 89.28 MHz
  );
  end generate;

  g_double_pll: if false generate
  clk_double_pll1: entity work.clk_25M_200M
  port map
  (
      CLKI        =>  clk_25MHz,
      CLKOP       =>  clk_200MHz
  );
  clk_double_pll2: entity work.clk_200M_60M_48M_12M_7M5
  port map
  (
      CLKI        =>  clk_200MHz,
      CLKOP       =>  clk_60MHz,
      CLKOS       =>  clk_48MHz,
      CLKOS2      =>  clk_12MHz,
      CLKOS3      =>  clk_7M5Hz
  );
  end generate;

  -- TX/RX passthru
  --ftdi_rxd <= wifi_txd;
  --wifi_rxd <= ftdi_txd;

  wifi_en <= '1';
  wifi_gpio0 <= R_rst_btn;
  
  -- USB-SERIAL soft-core
  usb_serial_core: entity work.usbtest
  port map
  (
    CLK => clk_89MHz, -- application clock, any freq 7.5-200 MHz
    led => S_led,
    dsctyp => S_dsctyp, -- debug shows descriptor type
    BREAK => S_BREAK,
    PHY_DATABUS16_8 => S_DATABUS16_8,
    PHY_RESET => S_RESET,
    PHY_XCVRSELECT => S_XCVRSELECT,
    PHY_TERMSELECT => S_TERMSELECT,
    PHY_OPMODE => S_OPMODE,
    PHY_CLKOUT => clk_usb, -- 48 or 60 MHz
    PHY_TXVALID => S_TXVALID,
    PHY_DATAOUT => S_DATAOUT,
    PHY_TXREADY => S_TXREADY,
    PHY_RXVALID => S_RXVALID,
    PHY_DATAIN => S_DATAIN,
    PHY_RXACTIVE => S_RXACTIVE,
    PHY_RXERROR => S_RXERROR,
    PHY_LINESTATE => S_LINESTATE
  );

  G_internal_usb_phy: if not C_external_ulpi generate
  clk_usb <= clk_48MHz; -- 48 MHz with "usb_rx_phy_48MHz.vhd" or 60 MHz with "usb_rx_phy_60MHz.vhd"
  -- USB1.1 PHY soft-core
  usb11_phy: entity work.usb_phy
  generic map
  (
    usb_rst_det => true
  )
  port map
  (
    clk => clk_usb, -- 48 MHz or 60 MHz
    rst => '1', -- 1-don't reset, 0-hold reset
    phy_tx_mode => '1', -- 1-differential, 0-single-ended
    usb_rst => S_usb_rst, -- USB host requests reset, sending signal to usb-serial core
    -- UTMI interface to usb-serial core
    TxValid_i => S_TXVALID,
    DataOut_i => S_DATAOUT, -- 8-bit TX
    TxReady_o => S_TXREADY,
    RxValid_o => S_RXVALID,
    DataIn_o => S_DATAIN, -- 8-bit RX
    RxActive_o => S_RXACTIVE,
    RxError_o => S_RXERROR,
    LineState_o => S_LINESTATE, -- 2-bit
    -- debug interface
    sync_err_o => S_sync_err,
    bit_stuff_err_o => S_bit_stuff_err,
    byte_err_o => S_byte_err,
    -- transciever interface to hardware
    rxd => S_rxd, -- differential input from D+
    rxdp => S_rxdp, -- single-ended input from D+
    rxdn => S_rxdn, -- single-ended input from D-
    txdp => S_txdp, -- single-ended output to D+
    txdn => S_txdn, -- single-ended output to D-
    txoe => S_txoe  -- 3-state control: 0-output, 1-input
  );
  -- transciever soft-core
  usb_fpga_pu_dp <= '1'; -- D+ pullup for USB1.1 device mode
  usb_fpga_pu_dn <= 'Z'; -- D- no pullup for USB1.1 device mode
  S_rxd <= usb_fpga_dp; -- differential input reads D+
  --S_rxd <= usb_fpga_bd_dp; -- single-ended input reads D+ may work as well
  S_rxdp <= usb_fpga_bd_dp; -- single-ended input reads D+
  S_rxdn <= usb_fpga_bd_dn; -- single-ended input reads D-
  usb_fpga_bd_dp <= S_txdp when S_txoe = '0' else 'Z';
  usb_fpga_bd_dn <= S_txdn when S_txoe = '0' else 'Z';
  end generate G_internal_usb_phy;

  G_external_usb_phy: if C_external_ulpi generate
  external_ulpi: ulpi_wrapper
  port map
  (
      -- UTMI Interface (SIE) to core
      utmi_op_mode_i => S_OPMODE,
      utmi_linestate_o => S_LINESTATE, -- 2-bit
      utmi_txvalid_i => S_TXVALID,
      utmi_data_in_o => S_DATAIN, -- 8-bit TX
      utmi_txready_o => S_TXREADY,
      utmi_rxvalid_o => S_RXVALID,
      utmi_data_out_i => S_DATAOUT, -- 8-bit RX
      utmi_rxactive_o => S_RXACTIVE,
      utmi_rxerror_o => S_RXERROR,
      utmi_xcvrselect_i => "01", -- peripheral FS (full speed) tusb3340 p.20
      utmi_termselect_i => '1', -- peripheral FS (full speed) tusb3340 p.20
      utmi_dppulldown_i => '0', -- peripheral FS (full speed) tusb3340 p.20
      utmi_dmpulldown_i => '0',  -- peripheral FS (full speed) tusb3340 p.20
      -- ULPI Interface (PHY) to chip e.g. TUSB3340
      ulpi_clk60_i => clk_usb,  -- input clock 60 MHz
      ulpi_rst_i => gn(0),
      ulpi_data_out_i => S_ulpi_data_out_i,
      ulpi_data_in_o => S_ulpi_data_in_o,
      ulpi_dir_i => S_ulpi_dir_i, -- '1' wrapper reads ulpi_data_out_i, '0' wrapper writes ulpi_data_in_o
      ulpi_nxt_i => gn(9),
      ulpi_stp_o => gp(10)
  );
  S_ulpi_dir_i <= gp(9);
  S_ulpi_data_out_i <= gp(8 downto 1);
  gp(8 downto 1) <= S_ulpi_data_in_o when S_ulpi_dir_i = '0' else (others => 'Z');
  clk_usb <= gp(0);
  end generate G_external_usb_phy;

  -- see the HID report on the OLED
  g_oled: if true generate
  process(clk_usb)
  begin
    if rising_edge(clk_usb) then
      R_rst_btn <= btn(0);
      if S_sync_err = '1' then
        R_sync_err <= R_sync_err + 1;
      end if;
      if S_bit_stuff_err = '1' then
        R_bit_stuff_err <= R_bit_stuff_err + 1;
      end if;
      if S_byte_err = '1' then
        R_byte_err <= R_byte_err + 1;
      end if;
      R_OPMODE <= S_OPMODE;
      R_LINESTATE <= S_LINESTATE; -- 2-bit
      R_TXVALID <= S_TXVALID;
      if S_TXVALID = '1' then
        R_DATAIN <= S_DATAIN;
      end if;
      R_TXREADY <= S_TXREADY;
      if S_RXVALID = '1' then
        R_DATAOUT <= S_DATAOUT;
      end if;
      R_RXVALID <= S_RXVALID;
      R_RXACTIVE <= S_RXACTIVE;
      if S_RXERROR = '1' then
        R_RXERROR <= R_RXERROR + 1;
      end if;
    end if;  
  end process;
  S_hid_report(55 downto 52) <= R_sync_err;
  S_hid_report(51 downto 48) <= R_bit_stuff_err;
  S_hid_report(47 downto 44) <= R_byte_err;
  S_hid_report(41 downto 40) <= R_OPMODE;
  S_hid_report(37 downto 36) <= R_LINESTATE;
  S_hid_report(32) <= R_TXVALID;
  S_hid_report(31 downto 24) <= R_DATAIN;
  S_hid_report(20) <= R_TXREADY;
  S_hid_report(16) <= R_RXVALID;
  S_hid_report(15 downto 8) <= R_DATAOUT;
  S_hid_report(4) <= R_RXACTIVE;
  S_hid_report(3 downto 0) <= R_RXERROR;
  oled_inst: entity work.oled_hex_decoder
  generic map
  (
    C_data_len => S_hid_report'length
  )
  port map
  (
    clk => clk_7M5Hz,
    en => '1',
    data => S_hid_report(63 downto 0),
    spi_resn => oled_resn,
    spi_clk => oled_clk,
    spi_csn => oled_csn,
    spi_dc => oled_dc,
    spi_mosi => oled_mosi
  );
  end generate;

  led(7 downto 4) <= R_RXERROR;
  -- led(3) <= S_usb_rst; -- blue, blinks on USB reset
  led(3) <= S_BREAK; -- blue lights during serial break
  led(2) <= S_led; -- green, should blink when enumerated
  led(1 downto 0) <= S_LineState; -- orange/red

end Behavioral;
