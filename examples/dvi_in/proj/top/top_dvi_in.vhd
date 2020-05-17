library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library ecp5u;
use ecp5u.components.all;

entity top_dvi_in is
Port
( 
  clk_25mhz     : in STD_LOGIC;
  -- Control signals
  led           : out   std_logic_vector(7 downto 0);
  sw            : in    std_logic_vector(3 downto 0);
  btn           : in    std_logic_vector(6 downto 0);
        
  wifi_gpio0: out  std_logic;

  -- Digital Video monitor output
  -- picture to be analyzed will be displayed here
  gpdi_dp, gpdi_dn: out std_logic_vector(3 downto 0);

  -- control lines as input with pullups to activate hotplug autodetection
  -- to enable hotplug, gpdi_ethn capacitor should be bypassed by 470 ohm resistor
  -- it's a C closest to the DIP switch
  gpdi_ethp, gpdi_ethn: inout std_logic;
  gpdi_cec: in std_logic;

  -- i2c shared for digital video and RTC
  gpdi_scl: in std_logic;
  gpdi_sda: inout std_logic;
  gn8,gn13: inout std_logic;
  gp: out std_logic_vector(27 downto 13);
  gpa, gna: in std_logic_vector(12 downto 9);
  gpb: inout std_logic_vector(8 downto 0);
  gnb: inout std_logic_vector(6 downto 0);
  gn: inout std_logic_vector(27 downto 13);
  -- For dumping symbols
  ftdi_rxd : out std_logic      
);
end;

architecture Behavioral of top_dvi_in is
    signal clk_100, locked: std_logic;
    signal clk_pixel, clk_shift: std_logic;
    signal reset_pll, reset_pll_blink: std_logic;
    signal reset: std_logic;
    signal phasesel: std_logic_vector(1 downto 0);
    signal des_red, des_green, des_blue: std_logic_vector(9 downto 0); -- deserialized 10-bit TMDS
    signal vga_red, vga_green, vga_blue: std_logic_vector(7 downto 0); -- 8-bit RGB color decoded
    signal vga_hsync, vga_vsync, vga_blank: std_logic; -- frame control
    signal fin_clock, fin_red, fin_green, fin_blue: std_logic_vector(1 downto 0); -- VGA back to final TMDS
begin
  --  led <= rec_red;
    wifi_gpio0 <= btn(0);
    gpdi_ethn <= '1' when btn(0) = '1' else '0';
    gn13 <= '1' when btn(0) = '1' else '0'; -- eth- hotplug
    reset <= not btn(0);
--  If pll is not locked connect blink to PLL block     
    reset_pll <= '0' when locked = '1' else reset_pll_blink;

    
    -- connect output to monitor Second PMOD on RIGHT BOTTOM
    -- not should show picture with all colors inverted
    gp(15) <= not gpa(12);
    gp(16) <= not gpa(11);
    gp(17) <= not gpa(10);
    gp(18) <= not gpa(9);

    -- clock recovery PLL with reset and lock
    clk_video_inst: entity work.clk_25_dvi_in_vhd
    port map
    (
      clki         => gpa(12), -- take tmds clock as input
      --clki       => clk_25mhz, -- onobard clock
      clk_sys      => clk_100,
      clk_pixel    => clk_pixel,
      clk_shift    => clk_shift,
      phasesel     => phasesel,   -- output2 "10"-clk_pixel, output1 "01"-clk_shift
      phasedir     => '0',
      phasestep    => btn(1), -- need debounce
      phaseloadreg => btn(2), -- need debounce
      locked       => locked,
      reset        => reset_pll
    );
    
    -- hold btn3 for fine selection
    phasesel <= "01" when btn(3)='1' else "10";

    -- Used for reseting PLL block
    blink_clock_recovery_inst: entity work.blink
    generic map
    (
      bits => 26
    )
    port map
    (
      clk => clk_25mhz,
      led(7) => reset_pll_blink
    );
    
    -- Used for indication of working clock recovery
    blink_shift_inst: entity work.blink
    generic map
    (
      bits => 26
    )
    port map
    (
      clk => clk_pixel,
      led(7) => led(6) -- If blinks - clock recovery works
    );

    -- PLL locked if on
    led(7) <= locked;
    led(5) <= '0';
    -- H-V sync ready for output
    led(4) <= vga_hsync;
    led(3) <= vga_vsync;
    -- blue color data
    led(2 downto 0) <= vga_blue(2 downto 0);

    -- Output to VGA PMOD - UPPER LEFT 
    gnb(0) <= vga_vsync;
    gpb(0) <= vga_hsync;
    gnb(1) <= vga_red(7);
    gpb(1) <= vga_red(6);
    gnb(2) <= vga_red(5);
    gpb(2) <= vga_green(7);
    gnb(3) <= vga_green(6);
    gpb(3) <= vga_green(5);
    gnb(4) <= vga_blue(7);
    gpb(4) <= vga_blue(6);
    gnb(5) <= vga_blue(5);
    gpb(5) <= vga_red(4);
    gnb(6) <= vga_green(4);
    gpb(6) <= vga_blue(4);

    i_edid_rom: entity work.edid_rom
    port map
    (
             clk        => clk_25mhz,
             sclk_raw   => gn8,
             sdat_raw   => gpb(8),
             edid_debug => open
    );
    
    --gpdi_dp(3) <= fin_clock(0);
    gpdi_dp(2) <= fin_red(0);
    --gpdi_dp(1) <= fin_green(0);
    --gpdi_dp(0) <= fin_blue(0);

    -- deserialize tmds_p to parallel 10-bit
    -- clk_pixel and clk_shift must be phase aligned with tmds_p(3) clock
    tmds_deserializer_inst: entity work.tmds_deserializer
    port map
    (
      clk_pixel  => clk_pixel,
      clk_shift  => clk_shift,
      tmds_p     => gpa(12 downto 9),
      outp_red   => des_red,
      outp_green => des_green,
      outp_blue  => des_blue
    );

    tmds_serializer_red_inst: entity work.serialiser_10_to_1
    port map
    (
      clk => clk_pixel,
      clk_x5 => clk_shift,
      reset => '0',
      data => des_red,
      serial => open -- gpdi_dp(2)
    );

    tmds_serializer_green_inst: entity work.serialiser_10_to_1
    port map
    (
      clk => clk_pixel,
      clk_x5 => clk_shift,
      reset => '0',
      data => des_green,
      serial => gpdi_dp(1)
    );

    tmds_serializer_blue_inst: entity work.serialiser_10_to_1
    port map
    (
      clk => clk_pixel,
      clk_x5 => clk_shift,
      reset => '0',
      data => des_blue,
      serial => gpdi_dp(0)
    );

    gpdi_dp(3) <= clk_pixel;

    -- parallel 10-bit TMDS to 8-bit RGB VGA converter
    dvi2vga_inst: entity work.dvi2vga
    port map
    (
      clk       => clk_pixel,
      dvi_red   => des_red,
      dvi_green => des_green,
      dvi_blue  => des_blue,
      vga_red   => vga_red,
      vga_green => vga_green,
      vga_blue  => vga_blue,
      vga_hsync => vga_hsync,
      vga_vsync => vga_vsync,
      vga_blank => vga_blank
    );
    -- VGA back to DVI-D
    vga2dvid_inst: entity work.vga2dvid
    port map
    (
      clk_pixel => clk_pixel,
      clk_shift => clk_shift,
      in_red    => vga_red,
      in_green  => vga_green,
      in_blue   => vga_blue,
      in_blank  => vga_blank,
      in_hsync  => vga_hsync,
      in_vsync  => vga_vsync,
      out_red   => fin_red,
      out_green => fin_green,
      out_blue  => fin_blue,
      out_clock => fin_clock
    );
    --gpdi_dp(3) <= fin_clock(0);
    gpdi_dp(2) <= fin_red(0);
    --gpdi_dp(1) <= fin_green(0);
    --gpdi_dp(0) <= fin_blue(0);

end Behavioral;
