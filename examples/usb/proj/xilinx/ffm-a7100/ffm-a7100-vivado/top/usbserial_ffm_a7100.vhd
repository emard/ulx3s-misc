----------------------------
-- Top level for USBSERIAL
-- http://github.com/emard
----------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.ALL;
use IEEE.numeric_std.all;

-- vendor specific library for ddr and differential video out
library unisim;
use unisim.vcomponents.all;

entity usbserial_ffm_a7100 is
generic
(
  C_external_ulpi: boolean := true
);
port
(
  clk_100mhz_n, clk_100mhz_p: in std_logic;
  usb_clk, usb_nxt: in std_logic;
  usb_dir, usb_stp: out std_logic;
  usb_d: inout std_logic_vector(7 downto 0);
  fioa: inout std_logic_vector(7 downto 0)
);
end;

architecture struct of usbserial_ffm_a7100 is
  alias led_green: std_logic is fioa(5); -- green LED
  alias led_red: std_logic is fioa(7); -- red LED

  signal clk_100MHz, clk_fb: std_logic;
  signal clk_60MHz: std_logic;
  signal R_red, R_green: std_logic_vector(26 downto 0);

  signal S_led: std_logic;
  signal S_usb_rst: std_logic;
  signal clk_usb_60MHz: std_logic;
  --signal S_rxdp, S_rxdn: std_logic;
  --signal S_txdp, S_txdn, S_txoe: std_logic;
  --signal S_hid_report: std_logic_vector(63 downto 0);
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
  signal S_ulpi_data_out_i, S_ulpi_data_in_o: std_logic_vector(7 downto 0);
  signal S_ulpi_dir_i: std_logic;

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
  clkin_ibufgds: ibufgds
  port map (I => clk_100MHz_P, IB => clk_100MHz_N, O => clk_100MHz);

  clk_main: mmcme2_base
  generic map
  (
    clkin1_period    => 10.0,		-- 10 ns period = 100 MHz
    clkfbout_mult_f  => 12.0,		-- 1200   MHz x12 common multiply
    clkout0_divide_f => 12.0,		--  100   MHz /12 divide
    clkout1_divide   => 160,		--    7.5 MHz /160 divide
    clkout2_divide   => 20,		--   60   MHz /20 divide
    bandwidth        => "LOW"
  )
  port map
  (
    pwrdwn   => '0',
    rst      => '0',
    clkin1   => clk_100MHz,
    clkfbin  => clk_fb,
    clkfbout => clk_fb,
    clkout0  => open,
    clkout1  => open,
    clkout2  => clk_60MHz,
    locked   => open
  );
  
  process(clk_60MHz)
  begin
    if rising_edge(clk_60MHz) then
      R_red <= R_red + 1;
    end if;
  end process;
  led_red <= R_red(R_red'high);

  process(clk_usb_60MHz)
  begin
    if rising_edge(clk_usb_60MHz) then
      R_green <= R_green + 1;
    end if;
  end process;
  led_green <= R_green(R_green'high);

--  usbserial_module: entity work.snake
--  port map
--  (
--    VGA_clk    => clk_pixel,
--    start      => reset_n
--  );

  -- USB-SERIAL core
  usb_serial_core: entity work.usbtest
  port map
  (
    led => S_led,
    dsctyp => S_dsctyp,
    PHY_DATABUS16_8 => S_DATABUS16_8,
    PHY_RESET => S_RESET,
    PHY_XCVRSELECT => S_XCVRSELECT,
    PHY_TERMSELECT => S_TERMSELECT,
    PHY_OPMODE => S_OPMODE,
    PHY_LINESTATE => S_LINESTATE,
    PHY_CLKOUT => clk_usb_60MHz,
    PHY_TXVALID => S_TXVALID,
    PHY_TXREADY => S_TXREADY,
    PHY_RXVALID => S_RXVALID,
    PHY_RXACTIVE => S_RXACTIVE,
    PHY_RXERROR => S_RXERROR,
    PHY_DATAIN => S_DATAIN,
    PHY_DATAOUT => S_DATAOUT
  );

  G_external_usb_phy: if C_external_ulpi generate
  external_ulpi: ulpi_wrapper
  port map
  (
      -- ULPI Interface (PHY)
      ulpi_clk60_i => clk_usb_60MHz,  -- input clock 60 MHz
      ulpi_rst_i => S_usb_rst,
      ulpi_data_out_i => S_ulpi_data_out_i,
      ulpi_data_in_o => S_ulpi_data_in_o,
      ulpi_dir_i => S_ulpi_dir_i, -- '1' wrapper reads ulpi_data_out_i, '0' wrapper writes ulpi_data_in_o
      ulpi_nxt_i => usb_nxt,
      ulpi_stp_o => usb_stp,
      -- UTMI Interface (SIE)
      utmi_txvalid_i => S_TXVALID,
      utmi_txready_o => S_TXREADY,
      utmi_rxvalid_o => S_RXVALID,
      utmi_rxactive_o => S_RXACTIVE,
      utmi_rxerror_o => S_RXERROR,
      utmi_data_in_o => S_DATAIN, -- 8-bit
      utmi_data_out_i => S_DATAOUT, -- 8-bit
      utmi_xcvrselect_i => "01", -- peripheral FS (full speed) tusb3340 p.20
      utmi_termselect_i => '1', -- peripheral FS (full speed) tusb3340 p.20
      utmi_op_mode_i => S_OPMODE,
      utmi_dppulldown_i => '0', -- peripheral FS (full speed) tusb3340 p.20
      utmi_dmpulldown_i => '0', -- peripheral FS (full speed) tusb3340 p.20
      utmi_linestate_o => S_LINESTATE -- 2-bit
  );
  usb_dir <= S_ulpi_dir_i;
  S_ulpi_data_out_i <= usb_d;
  usb_d <= S_ulpi_data_in_o when S_ulpi_dir_i = '0' else (others => 'Z');
  clk_usb_60MHz <= usb_clk;
  end generate;

end struct;
