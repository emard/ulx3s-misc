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

entity ulx3s_usbhost_test is
  generic
  (
    C_usb_full_speed: boolean := false -- false:6 MHz true:48 MHz
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

architecture Behavioral of ulx3s_usbhost_test is
  signal clk_200MHz, clk_100MHz, clk_89MHz, clk_60MHz, clk_48MHz, clk_12MHz, clk_7M5Hz: std_logic;
  signal clk_usb: std_logic; -- 48 or 60 MHz
  signal S_led: std_logic;
  signal S_usb_rst: std_logic;
  signal R_rst_btn: std_logic;
  signal R_phy_txmode: std_logic;
  signal S_rxd: std_logic;
  signal S_rxdp, S_rxdn: std_logic;
  signal S_txdp, S_txdn, S_txoe: std_logic;
  signal S_oled: std_logic_vector(63 downto 0);
  signal S_dsctyp: std_logic_vector(2 downto 0);
  signal S_DATABUS16_8: std_logic;
  signal S_RESET: std_logic;
  signal S_XCVRSELECT: std_logic_vector(1 downto 0);
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
  signal S_dppulldown, S_dmpulldown: std_logic;
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

  G_usb_full_speed: if C_usb_full_speed generate
  clk_usb <= clk_48MHz; -- 48 MHz with "usb_rx_phy_48MHz.vhd" or 60 MHz with "usb_rx_phy_60MHz.vhd"

  -- transciever soft-core
  usb_fpga_pu_dp <= '0' when S_dppulldown = '0' else 'Z'; -- D+ pullup for USB1.1 device mode
  usb_fpga_pu_dn <= '0' when S_dmpulldown = '0' else 'Z'; -- D- no pullup for USB1.1 device mode
  S_rxd <= usb_fpga_dp; -- differential input reads D+
  --S_rxd <= usb_fpga_bd_dp; -- single-ended input reads D+ may work as well
  S_rxdp <= usb_fpga_bd_dp; -- single-ended input reads D+
  S_rxdn <= usb_fpga_bd_dn; -- single-ended input reads D-
  usb_fpga_bd_dp <= S_txdp when S_txoe = '0' else 'Z';
  usb_fpga_bd_dn <= S_txdn when S_txoe = '0' else 'Z';
  end generate;

  G_usb_low_speed: if not C_usb_full_speed generate
  clk_usb <= clk_7M5Hz; -- FIXME: should be 6 MHz

  -- transciever soft-core
  -- for low speed USB, here are swaped D+ and D-
  usb_fpga_pu_dp <= '0' when S_dmpulldown = '0' else 'Z'; -- D+ pullup for USB1.0 device mode
  usb_fpga_pu_dn <= '0' when S_dppulldown = '0' else 'Z'; -- D- no pullup for USB1.0 device mode
  S_rxd <= not usb_fpga_dp; -- differential input reads inverted D+ for low speed
  --S_rxd <= usb_fpga_bd_dp; -- single-ended input reads D+ may work as well
  S_rxdp <= usb_fpga_bd_dn; -- single-ended input reads D- for low speed
  S_rxdn <= usb_fpga_bd_dp; -- single-ended input reads D+ for low speed
  usb_fpga_bd_dp <= S_txdn when S_txoe = '0' else 'Z';
  usb_fpga_bd_dn <= S_txdp when S_txoe = '0' else 'Z';
  end generate;

  -- USB1.1 PHY soft-core
  usb11_phy: entity work.usb_phy
  generic map
  (
    usb_rst_det => true
  )
  port map
  (
    clk => clk_usb, -- full speed: 48 MHz or 60 MHz, low speed: 6 MHz or 7.5 MHz
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

  -- USB-HOST soft-core
  usb_host_core: entity work.usbh_host_vhdl
  generic map
  (
    clk_freq_hz => 6000000, -- Hz (low speed: 6 MHz or 7.5 MHz)
    clk_div     => 4        -- 4@6MHz or 5@7.5MHz
  )
  port map
  (
    clk_i => clk_usb, -- low speed: 6 MHz or 7.5 MHz, high speed: 48 MHz or 60 MHz
    rst_i => btn(1),

    cfg_awvalid_i => '0', -- debug shows descriptor type
    cfg_awaddr_i => (others => '0'),
    cfg_wvalid_i => '0',
    cfg_wdata_i => (others => '0'),
    cfg_wstrb_i => (others => '0'),
    cfg_bready_i => '0',
    cfg_arvalid_i => '0',
    cfg_araddr_i => (others => '0'),
    cfg_rready_i => '0',
    cfg_awready_o => open,
    cfg_wready_o => open,
    cfg_bvalid_o => open,
    cfg_bresp_o => open,
    cfg_arready_o => open,
    cfg_rvalid_o => open,
    cfg_rdata_o => open,
    cfg_rresp_o => open,
    intr_o => open,

    utmi_data_in_i => S_DATAIN,
    utmi_txready_i => S_TXREADY,
    utmi_rxvalid_i => S_RXVALID,
    utmi_rxactive_i => S_RXACTIVE,
    utmi_rxerror_i => S_RXERROR,
    utmi_linestate_i => S_LINESTATE,
    utmi_data_out_o => S_DATAOUT,
    utmi_txvalid_o => S_TXVALID,
    utmi_op_mode_o => S_OPMODE,
    utmi_xcvrselect_o => S_XCVRSELECT,
    utmi_termselect_o => S_TERMSELECT,
    utmi_dppulldown_o => S_dppulldown,
    utmi_dmpulldown_o => S_dmpulldown
  );

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
  S_oled(55 downto 52) <= R_sync_err;
  S_oled(51 downto 48) <= R_bit_stuff_err;
  S_oled(47 downto 44) <= R_byte_err;
  S_oled(41 downto 40) <= R_OPMODE;
  S_oled(37 downto 36) <= R_LINESTATE;
  S_oled(32) <= R_TXVALID;
  S_oled(31 downto 24) <= R_DATAIN;
  S_oled(20) <= R_TXREADY;
  S_oled(16) <= R_RXVALID;
  S_oled(15 downto 8) <= R_DATAOUT;
  S_oled(4) <= R_RXACTIVE;
  S_oled(3 downto 0) <= R_RXERROR;
  oled_inst: entity work.oled_hex_decoder
  generic map
  (
    C_data_len => S_oled'length
  )
  port map
  (
    clk => clk_7M5Hz,
    en => '1',
    data => S_oled(63 downto 0),
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
  -- linestate: low full speed
  -- led(0):     D-  D+
  -- led(1):     D+  D-
  led(1 downto 0) <= S_LineState; -- orange/red

end Behavioral;
