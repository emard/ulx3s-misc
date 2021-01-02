-- (c)EMARD
-- License=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.numeric_std.ALL;

-- for diamond (not for opensource tools yosys/trellis)
--library ecp5u;
--use ecp5u.components.all;

entity top_spi_char is
  generic
  (
    x        : natural :=  640; -- pixels
    y        : natural :=  480; -- pixels
    f        : natural :=   60; -- Hz 60,50,30
    xadjustf : integer :=    0; -- adjust -3..3 if no picture
    yadjustf : integer :=    0; -- or to fine-tune f
    c_ddr    : natural :=    1  -- 0:SDR 1:DDR
  );
  port
  (
    clk_25mhz   : in    std_logic;  -- main clock input from 25MHz clock source

    -- Onboard blinky
    led         : out   std_logic_vector(7 downto 0);
    btn         : in    std_logic_vector(6 downto 0);

    -- GPIO (some are shared with wifi and adc)
    gp, gn      : in    std_logic_vector(27 downto 0);

    ftdi_txd    : in    std_logic;
    ftdi_rxd    : out   std_logic;
    ftdi_nrts   : in    std_logic;
    ftdi_ndtr   : in    std_logic;

    -- WiFi additional signaling
    wifi_txd    : in    std_logic;
    wifi_rxd    : out   std_logic;
    wifi_gpio16 : inout std_logic;
    wifi_gpio5  : in    std_logic;
    wifi_gpio0  : out   std_logic;
    --wifi_gpio17 : inout std_logic;

    -- Digital Video (differential outputs)
    gpdi_dp     : out   std_logic_vector(3 downto 0)
  );
end;

architecture Behavioral of top_spi_char is

  type T_video_timing is record
    x                  : natural;
    hsync_front_porch  : natural;
    hsync_pulse_width  : natural;
    hsync_back_porch   : natural;
    y                  : natural;
    vsync_front_porch  : natural;
    vsync_pulse_width  : natural;
    vsync_back_porch   : natural;
    f_pixel            : natural;
  end record T_video_timing;

  type T_possible_freqs is array (natural range <>) of natural;
  constant c_possible_freqs: T_possible_freqs :=
  (
    25000000,
    27000000,
    40000000,
    50000000,
    54000000,
    60000000,
    65000000,
    75000000,
    80000000,  -- overclock 400MHz
    100000000, -- overclock 500MHz
    108000000, -- overclock 540MHz
    120000000  -- overclock 600MHz
  );

  function F_find_next_f(f: natural)
    return natural is
      variable f0: natural := 0;
    begin
      for fx in c_possible_freqs'range loop
        if c_possible_freqs(fx)>f then
          f0 := c_possible_freqs(fx);
          exit;
        end if;
      end loop;
      return f0;
    end F_find_next_f;

  function F_video_timing(x,y,f: integer)
    return T_video_timing is
      variable video_timing : T_video_timing;
      variable xminblank   : natural := x/64; -- initial estimate
      variable yminblank   : natural := y/64; -- for minimal blank space
      variable min_pixel_f : natural := f*(x+xminblank)*(y+yminblank);
      variable pixel_f     : natural := F_find_next_f(min_pixel_f);
      variable yframe      : natural := y+yminblank;
      variable xframe      : natural := pixel_f/(f*yframe);
      variable xblank      : natural := xframe-x;
      variable yblank      : natural := yframe-y;
    begin
      video_timing.x                 := x;
      video_timing.hsync_front_porch := xblank/3;
      video_timing.hsync_pulse_width := xblank/3;
      video_timing.hsync_back_porch  := xblank-video_timing.hsync_pulse_width-video_timing.hsync_front_porch+xadjustf;
      video_timing.y                 := y;
      video_timing.vsync_front_porch := yblank/3;
      video_timing.vsync_pulse_width := yblank/3;
      video_timing.vsync_back_porch  := yblank-video_timing.vsync_pulse_width-video_timing.vsync_front_porch+yadjustf;
      video_timing.f_pixel           := pixel_f;

      return video_timing;
    end F_video_timing;

  constant video_timing : T_video_timing := F_video_timing(x,y,f);

  signal clocks: std_logic_vector(3 downto 0);
  signal clk_pixel, clk_shift: std_logic;
  signal clk_cpu: std_logic;
  signal vga_hsync, vga_vsync, vga_blank, vga_de: std_logic;
  signal vga_r, vga_g, vga_b: std_logic_vector(7 downto 0);
  signal dvid_red, dvid_green, dvid_blue, dvid_clock: std_logic_vector(1 downto 0);

  component ODDRX1F
    port (D0, D1, SCLK, RST: in std_logic; Q: out std_logic);
  end component;

  -- after OSD module 
  signal osd_vga_r, osd_vga_g, osd_vga_b: std_logic_vector(7 downto 0);
  signal osd_vga_hsync, osd_vga_vsync, osd_vga_blank: std_logic;
  -- invert CS to get CSN
  signal spi_irq, spi_csn, spi_miso, spi_mosi, spi_sck: std_logic;
  signal spi_ram_wr, spi_ram_rd: std_logic;
  signal spi_ram_wr_data, spi_ram_rd_data: std_logic_vector(7 downto 0);
  signal spi_ram_addr: std_logic_vector(31 downto 0); -- MSB for ROMs
  signal R_cpu_control: std_logic_vector(7 downto 0);
  signal R_btn_joy: std_logic_vector(btn'range);

begin
  -- esp32 micropython console
  wifi_rxd <= ftdi_txd;
  ftdi_rxd <= wifi_txd;

  clk_pll: entity work.ecp5pll
  generic map
  (
      in_Hz => natural(25.0e6),
    out0_Hz => video_timing.f_pixel*5,
    out1_Hz => video_timing.f_pixel
  )
  port map
  (
    clk_i => clk_25MHz,
    clk_o => clocks
  );
  clk_shift <= clocks(0);
  clk_pixel <= clocks(1);
  clk_cpu   <= clocks(1);

  -- 64K RAM (BRAM)
  --ram64k: entity work.bram_true2p_2clk
  --generic map
  --(
  --	dual_port  => false,
  --	addr_width => 16,
  --	data_width => 8
  --)
  --port map
  --(
  --	clk_a      => clk32,
  --	addr_a     => ramAddr,
  --	we_a       => ramWeCE,
  --	data_in_a  => ramDataOut,
  --	data_out_a => ramDataIn
  --);

  process(clk_cpu)
  begin
    if rising_edge(clk_cpu) then
      R_btn_joy <= btn;
    end if;
  end process;

  -- ESP32 -> FPGA
  spi_csn <= not wifi_gpio5;
  spi_sck <= gn(11); -- wifi_gpio25
  spi_mosi <= gp(11); -- wifi_gpio26
  -- FPGA -> ESP32
  wifi_gpio16 <= spi_miso;
  wifi_gpio0 <= not spi_irq; -- wifi_gpio0 IRQ active low
  
  --led <= (others => '0');
  --led <= spi_ram_wr_data;
  --led <= spi_ram_addr(7 downto 0);
  led(7 downto 5) <= (others => '0');
  led(4) <= spi_irq;
  led(3) <= spi_csn;
  led(2) <= spi_sck;
  led(1) <= spi_mosi;
  led(0) <= spi_miso;
  --led(6 downto 0) <= R_btn_joy;

  spi_slave_ram_btn: entity work.spi_ram_btn
  generic map
  (
    c_sclk_capable_pin => 0,
    c_addr_bits => 32
  )
  port map
  (
    clk => clk_cpu,
    csn => spi_csn,
    sclk => spi_sck,
    mosi => spi_mosi,
    miso => spi_miso,
    btn => R_btn_joy,
    irq => spi_irq,
    wr => spi_ram_wr,
    rd => spi_ram_rd,
    addr => spi_ram_addr,
    data_in => spi_ram_rd_data,
    data_out => spi_ram_wr_data
  );

  vga_instance: entity work.vga
  generic map
  (
    c_resolution_x      => video_timing.x,
    c_hsync_front_porch => video_timing.hsync_front_porch,
    c_hsync_pulse       => video_timing.hsync_pulse_width,
    c_hsync_back_porch  => video_timing.hsync_back_porch,
    c_resolution_y      => video_timing.y,
    c_vsync_front_porch => video_timing.vsync_front_porch,
    c_vsync_pulse       => video_timing.vsync_pulse_width,
    c_vsync_back_porch  => video_timing.vsync_back_porch,

    c_bits_x       =>  12,
    c_bits_y       =>  11
  )
  port map
  (
    clk_pixel  => clk_pixel,
    clk_pixel_ena => '1', -- R_slow_ena(R_slow_ena'high),
    test_picture => '1',
    --beam_x     => beam_x,
    --beam_y     => beam_y,
    vga_r      => vga_r,
    vga_g      => vga_g,
    vga_b      => vga_b,
    vga_hsync  => vga_hsync,
    vga_vsync  => vga_vsync,
    vga_blank  => vga_blank
    --vga_de     => vga_de
  );

  -- SPI OSD pipeline
  spi_osd_inst: entity work.spi_osd
  generic map
  (
    c_sclk_capable_pin => 0,
    c_start_x      => 64, c_start_y => 48, -- xy centering
    c_char_bits_x  =>  6, c_chars_y => 20, -- xy size, slightly less than full screen
    c_bits_x       => 11, c_bits_y  =>  9, -- xy counters bits
    c_inverse      =>  1, -- 1:support inverse video 0:no inverse video
    c_transparency =>  1, -- 1:semi-tranparent 0:opaque
    c_init_on      =>  1, -- 1:OSD initially shown without any SPI init
    c_char_file    => "osd.mem", -- initial OSD content
    c_font_file    => "font_bizcat8x16.mem"
  )
  port map
  (
    clk_pixel => clk_pixel, clk_pixel_ena => '1',
    i_r => std_logic_vector(vga_r(7 downto 0)),
    i_g => std_logic_vector(vga_g(7 downto 0)),
    i_b => std_logic_vector(vga_b(7 downto 0)),
    i_hsync => vga_hsync, i_vsync => vga_vsync, i_blank => vga_blank,
    i_csn => spi_csn, i_sclk => spi_sck, i_mosi => spi_mosi,
    o_r => osd_vga_r, o_g => osd_vga_g, o_b => osd_vga_b,
    o_hsync => osd_vga_hsync, o_vsync => osd_vga_vsync, o_blank => osd_vga_blank
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

    in_red    => osd_vga_r,
    in_green  => osd_vga_g,
    in_blue   => osd_vga_b,
    in_hsync  => osd_vga_hsync,
    in_vsync  => osd_vga_vsync,
    in_blank  => osd_vga_blank,

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
