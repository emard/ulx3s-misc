-- (c)EMARD
-- License=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--library ecp5u;
--use ecp5u.components.all;

entity top_vgatest is
  generic
  (
    x        : natural :=  640; -- pixels
    y        : natural :=  480; -- pixels
    f        : natural :=   60; -- Hz 60,50,30
    xadjustf : integer :=    0; -- adjust -3..3 if no picture
    yadjustf : integer :=    0; -- or to fine-tune f
    ext_gpdi : natural :=    1; -- 0:disable 1:enable external gpdi
    c_ddr    : natural :=    1  -- 0:SDR 1:DDR
  );
  port
  (
    clk_25mhz: in std_logic;  -- main clock input from 25MHz clock source

    -- Onboard blinky
    led: out std_logic_vector(7 downto 0);
    btn: in std_logic_vector(6 downto 0);

    -- GPIO (some are shared with wifi and adc)
    gp, gn: inout std_logic_vector(27 downto 0) := (others => 'Z');

    -- Digital Video (differential outputs)
    gpdi_dp: out std_logic_vector(3 downto 0)
  );
end;

architecture Behavioral of top_vgatest is
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
  signal vga_hsync, vga_vsync, vga_blank, vga_de: std_logic;
  signal vga_r, vga_g, vga_b: std_logic_vector(7 downto 0);
  signal dvid_red, dvid_green, dvid_blue, dvid_clock: std_logic_vector(1 downto 0);
  signal beam_x, beam_y: std_logic_vector(12 downto 0);
  
  signal R_slow_ena: std_logic_vector(10 downto 0);

  component ODDRX1F
    port (D0, D1, SCLK, RST: in std_logic; Q: out std_logic);
  end component;

begin
  clk_single_pll: entity work.ecp5pll
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
  
  process(clk_pixel)
  begin
    if rising_edge(clk_pixel) then
      if R_slow_ena(R_slow_ena'high)='0' then
        R_slow_ena <= R_slow_ena + 1;
      else
        R_slow_ena <= (others => '0');
      end if;
    end if;
  end process;

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
  
  led(0) <= vga_hsync;
  led(1) <= vga_vsync;
  led(7) <= vga_blank;

  vga2dvid_instance: entity work.vga2dvid
  generic map
  (
    c_ddr => '1',
    c_shift_clock_synchronizer => '0'
  )
  port map
  (
    clk_pixel => clk_pixel,
    clk_shift => clk_shift,
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
  ddr_clock: ODDRX1F port map (D0=>dvid_clock(0), D1=>dvid_clock(1), Q=>gpdi_dp(3), SCLK=>clk_shift, RST=>'0');
  ddr_red:   ODDRX1F port map (D0=>dvid_red(0),   D1=>dvid_red(1),   Q=>gpdi_dp(2), SCLK=>clk_shift, RST=>'0');
  ddr_green: ODDRX1F port map (D0=>dvid_green(0), D1=>dvid_green(1), Q=>gpdi_dp(1), SCLK=>clk_shift, RST=>'0');
  ddr_blue:  ODDRX1F port map (D0=>dvid_blue(0),  D1=>dvid_blue(1),  Q=>gpdi_dp(0), SCLK=>clk_shift, RST=>'0');

  g_external_gpdi:
  if ext_gpdi > 0 generate
  ddr_xclock: ODDRX1F port map (D0=>dvid_clock(0), D1=>dvid_clock(1), Q=>gp(12), SCLK=>clk_shift, RST=>'0');
  ddr_xred:   ODDRX1F port map (D0=>dvid_red(0),   D1=>dvid_red(1),   Q=>gp(11), SCLK=>clk_shift, RST=>'0');
  ddr_xgreen: ODDRX1F port map (D0=>dvid_green(0), D1=>dvid_green(1), Q=>gp(10), SCLK=>clk_shift, RST=>'0');
  ddr_xblue:  ODDRX1F port map (D0=>dvid_blue(0),  D1=>dvid_blue(1),  Q=>gp( 9), SCLK=>clk_shift, RST=>'0');
  end generate;

end Behavioral;
