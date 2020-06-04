-- (c)EMARD
-- License=BSD

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

--library ecp5u;
--use ecp5u.components.all;

entity top_lvds_passthru is
  generic
  (
    bits: integer := 27
  );
  port
  (
    clk_25mhz : in  std_logic;  -- main clock input from 25MHz clock source
    btn       : in  std_logic_vector(6 downto 0);
    gp        : out std_logic_vector(8 downto 0);
    gn        : out std_logic_vector(8 downto 0);
    gp_i      : in  std_logic_vector(12 downto 9);
    gp_o      : out std_logic_vector(6 downto 3);
    gpdi_dp   : out std_logic_vector(3 downto 0);
    led       : out std_logic_vector(7 downto 0)
  );
end;

architecture mix of top_lvds_passthru is
  type T_blink is array (0 to 3) of std_logic_vector(bits-1 downto 0);
  type T_pixel is array (3 downto 0) of std_logic_vector(6 downto 0);
  signal R_blink: T_blink;
  signal clocks, clocks_dvi: std_logic_vector(3 downto 0);
  alias clk_pixel: std_logic is clocks(1);
  alias clk_shift: std_logic is clocks(2);
  alias clk_shift_dvi: std_logic is clocks_dvi(0);
  signal R_btn_prev, R_btn_latch, R_btn: std_logic_vector(6 downto 0);
  signal R_btn_debounce: std_logic_vector(19 downto 0);
  signal input_delayed: std_logic_vector(3 downto 0);
  signal S_delay_limit: std_logic_vector(3 downto 0);
  signal R_lvds, R_pixel: T_pixel;
  signal vga_r, vga_g, vga_b: std_logic_vector(5 downto 0);
  signal vga_hsync, vga_vsync, vga_de, vga_blank: std_logic;
  signal dvid_red, dvid_green, dvid_blue, dvid_clock: std_logic_vector(1 downto 0);

  component ODDRX1F
    port (D0, D1, SCLK, RST: in std_logic; Q: out std_logic);
  end component;

begin
  clkgen_inst: entity work.ecp5pll
  generic map
  (
      in_Hz    => natural( 25.0e6),
    out0_Hz    => natural(175.0e6),
    out1_Hz    => natural( 25.0e6), out1_deg =>   0, -- clk_pixel   0, 0-30 340-359
    out2_Hz    => natural(175.0e6), out2_deg => 100, -- clk_shift 100, 40-150
    out3_Hz    => natural( 25.0e6),
    dynamic_en =>           1
  )
  port map
  (
    clk_i        => gp_i(12),
    clk_o        => clocks,
    phasesel     => "01", -- "10"=2:clk_shift "01"=1:clk_pixel
    phasedir     => R_btn(1),
    phasestep    => R_btn(3),
    phaseloadreg => '0',
    locked       => led(7)
  );

  clkgen_dvi_inst: entity work.ecp5pll
  generic map
  (
      in_Hz    => natural( 25.0e6),
    out0_Hz    => natural(125.0e6),
    dynamic_en =>           0
  )
  port map
  (
    clk_i        => gp_i(12),
    clk_o        => clocks_dvi
  );

  G_blinks: for i in 0 to 2
  generate
    process(clocks(i))
    begin
      if rising_edge(clocks(i)) then
        R_blink(i) <= R_blink(i)+1;
      end if;
      --led(2*i+1 downto 2*i) <= R_blink(i)(bits-1 downto bits-2);
    end process;
  end generate;

  -- BTN tracker
  process(clk_25mhz)
  begin
      if rising_edge(clk_25mhz) then
        R_btn_latch <= btn;
        if R_btn /= R_btn_latch and R_btn_debounce(R_btn_debounce'high) = '1' then
          R_btn_debounce <= (others => '0');
          R_btn <= R_btn_latch;
        else
          if R_btn_debounce(R_btn_debounce'high) = '0' then
            R_btn_debounce <= R_btn_debounce + 1;
          end if;
        end if;
        R_btn_prev <= R_btn;
      end if;
  end process;

  gn(8) <= '1'; -- normally PWM

  lvds2vga_inst: entity work.lvds2vga
  port map
  (
    clk_pixel => clk_pixel, clk_shift => clk_shift,
    lvds_i => gp_i(12 downto 9), -- cbgr
    r_o => vga_r, g_o => vga_g, b_o => vga_b,
    hsync_o => vga_hsync, vsync_o => vga_vsync, de_o => vga_de
  );

  vga2lvds_inst: entity work.vga2lvds
  port map
  (
    clk_pixel => clk_pixel,
    clk_shift => clk_shift,
    r_i     => vga_r,
    --r_i     => (others => '0'), -- red OFF (hardware bug with red channel)
    g_i     => vga_g,
    b_i     => vga_b,
    hsync_i => vga_hsync,
    vsync_i => vga_vsync,
    de_i    => vga_de,
    lvds_o  => gp_o(6 downto 3)
  );

  vga_blank <= not vga_de;
  vga2dvid_instance: entity work.vga2dvid
  generic map
  (
    C_ddr => '1',
    C_depth => 6,
    C_shift_clock_synchronizer => '0'
  )
  port map
  (
    clk_pixel => clk_pixel,
    clk_shift => clk_shift_dvi,
    in_red    => vga_r,
    in_green  => vga_g,
    in_blue   => vga_b,
    in_hsync  => vga_hsync,
    in_vsync  => vga_vsync,
    in_blank  => vga_blank,

    -- single-ended output ready for differential buffers
    out_red   => dvid_red,
    out_green => dvid_green,
    out_blue  => dvid_blue,
    out_clock => dvid_clock
  );

  -- vendor specific DDR modules
  -- convert SDR 2-bit input to DDR clocked 1-bit output (single-ended)
  ddr_clock: ODDRX1F port map (D0=>dvid_clock(0), D1=>dvid_clock(1), Q=>gpdi_dp(3), SCLK=>clk_shift_dvi, RST=>'0');
  ddr_red:   ODDRX1F port map (D0=>dvid_red(0),   D1=>dvid_red(1),   Q=>gpdi_dp(2), SCLK=>clk_shift_dvi, RST=>'0');
  ddr_green: ODDRX1F port map (D0=>dvid_green(0), D1=>dvid_green(1), Q=>gpdi_dp(1), SCLK=>clk_shift_dvi, RST=>'0');
  ddr_blue:  ODDRX1F port map (D0=>dvid_blue(0),  D1=>dvid_blue(1),  Q=>gpdi_dp(0), SCLK=>clk_shift_dvi, RST=>'0');

end mix;
