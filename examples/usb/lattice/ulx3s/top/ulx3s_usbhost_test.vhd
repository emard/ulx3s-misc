-- (c)EMARD
-- License=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library ecp5u;
use ecp5u.components.all;

entity ulx3s_usbhost_test is
  generic
  (
    -- enable only one US2/US3/US4
    C_us2: boolean := true;  -- onboard micro USB with OTG adapter
    C_us3: boolean := false; -- PMOD US3 at GP,GN 25,22,21
    C_us4: boolean := false; -- PMOD US4 at GP,GN 24,23,20
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
  gpdi_dp: out std_logic_vector(3 downto 0);

  -- Flash ROM (SPI0)
  --flash_miso   : in      std_logic;
  --flash_mosi   : out     std_logic;
  --flash_clk    : out     std_logic;
  --flash_csn    : out     std_logic;

  -- SD card (SPI1)
  --sd_d: inout std_logic_vector(3 downto 0) := (others => 'Z');
  --sd_clk, sd_cmd: inout std_logic := 'Z';
  --sd_cdn, sd_wp: inout std_logic := 'Z'; -- not connected

  -- SHUTDOWN: logic '1' here will shutdown power on PCB >= v1.7.5
  shutdown: out std_logic := '0'
  );
end;

architecture Behavioral of ulx3s_usbhost_test is

  -- PMOD with US3 and US4
  -- ULX3S pins up and flat cable: swap GP/GN and invert differential input
  -- ULX3S direct or pins down and flat cable: don't swap GP/GN, normal differential input

  alias us3_fpga_bd_dp: std_logic is gn(25);
  alias us3_fpga_bd_dn: std_logic is gp(25);

  alias us4_fpga_bd_dp: std_logic is gn(24);
  alias us4_fpga_bd_dn: std_logic is gp(24);
  
  alias us4_fpga_pu_dp: std_logic is gn(23);
  alias us4_fpga_pu_dn: std_logic is gp(23);
  
  alias us3_fpga_pu_dp: std_logic is gn(22);
  alias us3_fpga_pu_dn: std_logic is gp(22);

  alias us3_fpga_n_dp: std_logic is gp(21); -- flat cable
  signal us3_fpga_dp: std_logic; -- flat cable
  --alias us3_fpga_dp: std_logic is gp(21); -- direct

  alias us4_fpga_n_dp: std_logic is gp(20); -- flat cable
  signal us4_fpga_dp: std_logic; -- flat cable
  --alias us4_fpga_dp: std_logic is gp(20); -- direct

  signal clk_200MHz, clk_125MHz, clk_100MHz, clk_89MHz, clk_60MHz, clk_48MHz, clk_12MHz, clk_7M5Hz, clk_6MHz: std_logic;
  signal clk_usb: std_logic; -- 48 MHz
  signal S_led: std_logic;
  signal S_usb_rst: std_logic;
  signal R_rst_btn: std_logic;
  signal R_phy_txmode: std_logic;
  signal S_rxd: std_logic;
  signal S_rxdp, S_rxdn: std_logic;
  signal S_txdp, S_txdn, S_txoe: std_logic;
  signal S_oled: std_logic_vector(63 downto 0);
  signal S_valid: std_logic;
  signal R_byte0: std_logic_vector(7 downto 0);
  signal clk_pixel, clk_shift: std_logic; -- 25,125 MHz
  signal vga_hsync, vga_vsync, vga_blank: std_logic;
  signal vga_r, vga_g, vga_b: std_logic_vector(7 downto 0);
  signal dvid_red, dvid_green, dvid_blue, dvid_clock: std_logic_vector(1 downto 0);
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

  g_single_pll1: if true generate
  clk_single_pll1: entity work.clk_25_125_68_6_25
  port map
  (
      CLKI        =>  clk_25MHz,
      CLKOP       =>  open,
      CLKOS       =>  open,
      CLKOS2      =>  clk_6MHz,
      CLKOS3      =>  open
  );
  end generate;

  g_single_pll2: if true generate
  clk_single_pll2: entity work.clk_25_125_25_48_89
  port map
  (
      CLKI        =>  clk_25MHz,
      CLKOP       =>  clk_shift, -- 125 MHz
      CLKOS       =>  clk_pixel, -- 25 MHz
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
  
  clk_usb <= clk_6MHz; -- 48MHz full speed, 6MHz low speed

  G_us2: if C_us2 generate
  usb_fpga_pu_dp <= '0';
  usb_fpga_pu_dn <= '0';
  us2_hid_host_inst: entity usbh_host_hid
  generic map
  (
    C_usb_speed => '0' -- '0':Low-speed '1':Full-speed
  )
  port map
  (
    clk => clk_usb, -- 6 MHz for low-speed USB1.0 device or 48 MHz for full-speed USB1.1 device
    bus_reset => '0',
    usb_dif => usb_fpga_dp,    -- usb/us3/us4
    usb_dp  => usb_fpga_bd_dp, -- usb/us3/us4
    usb_dn  => usb_fpga_bd_dn, -- usb/us3/us4
    hid_report => S_oled,
    hid_valid => S_valid
  );
  end generate;
  
  G_us3: if C_us3 generate
  us3_fpga_pu_dp <= '0';
  us3_fpga_pu_dn <= '0';
  us3_fpga_dp <= not us3_fpga_n_dp; -- flat cable
  us3_hid_host_inst: entity usbh_host_hid
  generic map
  (
    C_usb_speed => '0' -- '0':Low-speed '1':Full-speed
  )
  port map
  (
    clk => clk_usb, -- 6 MHz for low-speed USB1.0 device or 48 MHz for full-speed USB1.1 device
    bus_reset => '0',
    usb_dif => us3_fpga_dp,    -- usb/us3/us4
    usb_dp  => us3_fpga_bd_dp, -- usb/us3/us4
    usb_dn  => us3_fpga_bd_dn, -- usb/us3/us4
    hid_report => S_oled,
    hid_valid => S_valid
  );
  end generate;

  G_us4: if C_us4 generate
  us4_fpga_pu_dp <= '0';
  us4_fpga_pu_dn <= '0';
  us4_fpga_dp <= not us4_fpga_n_dp; -- flat cable
  us4_hid_host_inst: entity usbh_host_hid
  generic map
  (
    C_usb_speed => '0' -- '0':Low-speed '1':Full-speed
  )
  port map
  (
    clk => clk_usb, -- 6 MHz for low-speed USB1.0 device or 48 MHz for full-speed USB1.1 device
    bus_reset => '0',
    usb_dif => us4_fpga_dp,    -- usb/us3/us4
    usb_dp  => us4_fpga_bd_dp, -- usb/us3/us4
    usb_dn  => us4_fpga_bd_dn, -- usb/us3/us4
    hid_report => S_oled,
    hid_valid => S_valid
  );
  end generate;

  oled_inst: entity work.oled_hex_decoder
  generic map
  (
    C_data_len => S_oled'length
  )
  port map
  (
    clk => clk_6MHz,
    en => '1',
    data => S_oled(63 downto 0),
    spi_resn => oled_resn,
    spi_clk => oled_clk,
    spi_csn => oled_csn,
    spi_dc => oled_dc,
    spi_mosi => oled_mosi
  );
  
  process(clk_6MHz)
  begin
    if rising_edge(clk_6MHz) then
      if S_valid = '1' then
        R_byte0 <= S_oled(7 downto 0);
      end if;
    end if;
  end process;
  --led <= R_byte0; -- report byte0 contains logitech mouse BTN state or keyboard SHIFT state

  vga_instance: entity work.vga
  port map
  (
      clk_pixel => clk_pixel,
      clk_pixel_ena => '1',
      test_picture => '1',
      red_byte => open,
      green_byte => open,
      blue_byte => open,
      vga_r => vga_r,
      vga_g => vga_g,
      vga_b => vga_b,
      vga_hsync => vga_hsync,
      vga_vsync => vga_vsync,
      vga_blank => vga_blank
  );

  vga2dvid_instance: entity work.vga2dvid
  generic map
  (
    C_ddr => '1',
    C_shift_clock_synchronizer => '0'
  )
  port map
  (
    clk_pixel => clk_pixel,
    clk_shift => clk_shift,
    in_red => vga_r,
    in_green => vga_g,
    in_blue => vga_b,
    in_hsync => vga_hsync,
    in_vsync => vga_vsync,
    in_blank => vga_blank,

    -- single-ended output ready for differential buffers
    out_red   => dvid_red,
    out_green => dvid_green,
    out_blue  => dvid_blue,
    out_clock => dvid_clock
  );

  -- vendor specific DDR modules
  -- convert SDR 2-bit input to DDR clocked 1-bit output (single-ended)
  ddr_clock: ODDRX1F port map (D0=>dvid_clock(0), D1=>dvid_clock(1), Q=>gpdi_dp(3), SCLK=>clk_shift, RST=>'0');
  ddr_red:   ODDRX1F port map (D0=>dvid_red(0),   D1=>dvid_red(1),   Q=>gpdi_dp(2), SCLK=>clk_shift, RST=>'0');
  ddr_green: ODDRX1F port map (D0=>dvid_green(0), D1=>dvid_green(1), Q=>gpdi_dp(1), SCLK=>clk_shift, RST=>'0');
  ddr_blue:  ODDRX1F port map (D0=>dvid_blue(0),  D1=>dvid_blue(1),  Q=>gpdi_dp(0), SCLK=>clk_shift, RST=>'0');

end Behavioral;
