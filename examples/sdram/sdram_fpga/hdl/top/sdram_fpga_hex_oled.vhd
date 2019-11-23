-- (c)EMARD
-- License=BSD

-- module to bypass user input and usbserial to esp32 wifi

--library IEEE;
--use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.STD_LOGIC_UNSIGNED.ALL;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ecp5u;
use ecp5u.components.all;

entity sdram_fpga_hex_oled is
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

  -- Flash ROM (SPI0)
  --flash_miso   : in      std_logic;
  --flash_mosi   : out     std_logic;
  --flash_clk    : out     std_logic;
  --flash_csn    : out     std_logic;

  -- SDRAM interface (For use with 16Mx16bit or 32Mx16bit SDR DRAM, depending on version)
  sdram_csn  : out   std_logic; -- chip select
  sdram_clk  : out   std_logic; -- clock to SDRAM
  sdram_cke  : out   std_logic; -- clock enable to SDRAM	
  sdram_rasn : out   std_logic; -- SDRAM RAS
  sdram_casn : out   std_logic; -- SDRAM CAS
  sdram_wen  : out   std_logic; -- SDRAM write-enable
  sdram_a    : out   unsigned(12 downto 0); -- SDRAM address bus
  sdram_ba   : out   unsigned( 1 downto 0); -- SDRAM bank-address
  sdram_dqm  : out   std_logic_vector( 1 downto 0); -- byte select
  sdram_d    : inout std_logic_vector(15 downto 0); -- data bus to/from SDRAM	

  -- SD card (SPI1)
  sd_dat3_csn, sd_cmd_di, sd_dat0_do, sd_dat1_irq, sd_dat2: inout std_logic := 'Z';
  sd_clk: inout std_logic := 'Z';
  sd_cdn, sd_wp: inout std_logic := 'Z'
  );
end;

architecture Behavioral of sdram_fpga_hex_oled is
  signal clk_100MHz, clk_60MHz, clk_7M5Hz, clk_12MHz: std_logic;
  signal S_reset, R_reset: std_logic;
  -- SDRAM
  signal clk_sdram: std_logic;
  signal R_request, R_write_enable, S_ack, S_read_data_valid: std_logic;
  signal R_write_data, S_read_data: std_logic_vector(31 downto 0);
  signal R_addr: unsigned(23 downto 0);
  -- READ/WRITE logic
  signal R_state, R_state_latch: unsigned(23 downto 0) := (others => '0');
  signal R_valid_latch, R_prev_read_data_valid: std_logic;
  signal R_read_data_latch: std_logic_vector(31 downto 0);
  -- signal S_data: std_logic_vector(6 downto 0);
  signal S_data: std_logic_vector(127 downto 0);
  signal R_counter: unsigned(63 downto 0);
  signal S_enable: std_logic;
begin
  clk_pll: entity work.clk_25M_100M_7M5_12M_60M
  port map
  (
      CLKI        =>  clk_25mhz,
      CLKOP       =>  clk_100MHz,
      CLKOS       =>  clk_7M5Hz,
      CLKOS2      =>  clk_12MHz,
      CLKOS3      =>  clk_60MHz
  );
  clk_sdram <= clk_100MHz;

  -- TX/RX passthru
  --ftdi_rxd <= wifi_txd;
  --wifi_rxd <= ftdi_txd;

  wifi_en <= '1';
  wifi_gpio0 <= btn(0);
  S_reset <= not btn(0);
  S_enable <= not btn(1); -- btn1 to hold
  
  process(clk_sdram)
  begin
    if rising_edge(clk_sdram) then
      R_state <= R_state + 1;
      R_reset <= S_reset;
    end if;
  end process;

  sdram_0bject_inst: entity sdram_0bject
  generic map
  (
    CLK_FREQ    => 100, -- MHz
    CAS_LATENCY => 2
  )
  port map
  (
    reset       => R_reset,
    clk         => clk_sdram,
    req         => R_request,
    ack         => S_ack,
    we          => R_write_enable,
    addr        => R_addr(22 downto 0),
    -- WRITE signaling
    data        => R_write_data,
    -- READ signaling
    valid       => S_read_data_valid,
    q           => S_read_data,
    -- SDRAM chip connection
    sdram_cke   => sdram_cke,
    sdram_we_n  => sdram_wen,
    sdram_ras_n => sdram_rasn,
    sdram_cas_n => sdram_casn,
    sdram_ba    => sdram_ba,
    sdram_a     => sdram_a,
    sdram_dq    => sdram_d,
    sdram_dqm   => sdram_dqm
  );
  sdram_clk <= not clk_sdram;

  -- writer
  process(clk_sdram)
  begin
    if rising_edge(clk_sdram) then
      case std_logic_vector(R_state) is
        when x"100000" =>
          R_request <= '1';
          R_write_enable <= '1';
          R_addr <= x"000300";
          R_write_data <= x"01234567";
        when x"900000" =>
          R_request <= '1';
          R_write_enable <= '1';
          R_addr <= x"000700";
          R_write_data <= x"600DCAFE";
        when x"300000" =>
          R_request <= '1';
          R_write_enable <= '0';
          if btn(2) = '1' then
            R_addr <= x"000700";
          else
            R_addr <= x"000300";
          end if;
        when others =>
          if R_request = '1' and S_ack = '1' then
            R_request <= '0';
          end if;
      end case;
    end if;
  end process;

  -- reader
  process(clk_sdram)
  begin
    if rising_edge(clk_sdram) then
      if R_write_enable = '0' and -- R_request = '0' and
      R_prev_read_data_valid = '0' and S_read_data_valid = '1' then
        R_state_latch <= R_state; -- display at which state we are
        R_read_data_latch <= S_read_data;
        R_valid_latch <= S_read_data_valid;
      end if;
      R_prev_read_data_valid <= S_read_data_valid;
    end if;
  end process;

  process(clk_12MHz)
  begin
    if rising_edge(clk_12MHz) then
      R_counter <= R_counter + 1;
    end if;
  end process;

  S_data <= R_write_data & R_read_data_latch
          & "000" & R_valid_latch & x"000000000" & std_logic_vector(R_state_latch);

  oled_inst: entity oled_hex_decoder
  generic map
  (
    C_data_len => S_data'length
  )
  port map
  (
    clk => clk_12MHz,
    clken => R_counter(0),
    en => S_enable,
    data => S_data,
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
