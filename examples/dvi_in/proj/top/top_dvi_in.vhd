library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- LED7 GPDI clock lock (should be ON constantly)
-- LED6 GPDI clock present (should blink)
-- LED5 hsync should pwm light fast, 1/4 intensity
-- LED4 vsync should pwm light 60Hz, very dim
-- LED2 red   delay end of range (initially OFF)
-- LED1 green delay end of range (intiially OFF)
-- LED0 blue  delay end of range (initially OFF)

-- if hsync/vsync are not as above,
-- BTN0 hotplug, reset delay and PLL
-- BTN1 delay direction (hold like shift key)
-- BTN2 not pressed - adjust clk_pixel, pressed - clk_shift
-- BTN3 PLL phase shift
-- BTN4 red delay
-- BTN5 green delay
-- BTN6 blue delay, press several times until hsync/vsync LEDs light properly

-- pressing BTN4-6 without BTN1 increases delay,
-- it is equivalent to PLL phase in positive direction
-- pressing BTN4-6 with BTN1 decreases delay
-- it is equivalent to PLL phase in negative direction
-- full range of delay covers PLL phase range of about 100 deg

library ecp5u;
use ecp5u.components.all;

entity top_dvi_in is
generic
(
  c_dvi2vga_bypass : natural := 0; -- 0:GPDI->VGA->GPDI, 1: 10-bit bypass
  c_vga_out        : natural := 0; -- 1:NO, 1:YES
  c_bits           : natural := 2  -- 1:SDR 250 MHz, 2:DDR 125 MHz
);
Port
( 
  clk_25mhz     : in STD_LOGIC;
  -- Control signals
  led           : out   std_logic_vector(7 downto 0);
  sw            : in    std_logic_vector(3 downto 0);
  btn           : in    std_logic_vector(6 downto 0);
        
  wifi_gpio0    : out  std_logic;

  oled_csn,
  oled_clk,
  oled_mosi,
  oled_dc,
  oled_resn     : out std_logic;

  -- Digital Video monitor output
  -- picture to be analyzed will be displayed here
  gpdi_dp       : out std_logic_vector(3 downto 0);

  -- control lines as input with pullups to activate hotplug autodetection
  -- to enable hotplug, gpdi_ethn capacitor should be bypassed by 470 ohm resistor
  -- it's a C closest to the DIP switch
  gpdi_ethp, gpdi_ethn: inout std_logic;
  gpdi_cec      : in std_logic;

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
--    component IDDRX1F
--      port (D, SCLK, RST: in std_logic; Q0, Q1: out std_logic);
--    end component;
--    component ODDRX1F
--      port (D0, D1, SCLK, RST: in std_logic; Q: out std_logic);
--    end component;
--    component DELAYF
--      port (A, LOADIN, MOVE, DIRECTION: in std_logic; Z, CFLAG: out std_logic);
--    end component; 
--    component DELAYG
--      port (A: in std_logic; Z: out std_logic);
--    end component;

    signal clocks: std_logic_vector(3 downto 0);
    signal clk_100, locked: std_logic;
    signal clk_pixel, clk_shift: std_logic;
    signal reset_pll, reset_pll_blink: std_logic;
    signal reset: std_logic;
    signal phasesel: std_logic_vector(1 downto 0);
    signal input_delayed: std_logic_vector(3 downto 0);
    signal tmds_c_i, tmds_r_i, tmds_g_i, tmds_b_i : std_logic_vector(c_bits-1 downto 0);
    signal tmds_c_o, tmds_r_o, tmds_g_o, tmds_b_o : std_logic_vector(c_bits-1 downto 0);
    signal des_red, des_green, des_blue: std_logic_vector(9 downto 0); -- deserialized 10-bit TMDS
    signal vga_red, vga_green, vga_blue: std_logic_vector(7 downto 0); -- 8-bit RGB color decoded
    signal vga_hsync, vga_vsync, vga_blank: std_logic; -- frame control
    signal fin_clock, fin_red, fin_green, fin_blue: std_logic_vector(1 downto 0); -- VGA back to final TMDS
    signal R_btn_prev, R_btn_latch, R_btn: std_logic_vector(6 downto 0);
    signal R_btn_debounce: std_logic_vector(19 downto 0);
    signal S_delay_limit: std_logic_vector(3 downto 0);
begin
  --  led <= rec_red;
    wifi_gpio0 <= R_btn(0);
    gpdi_ethn <= '1' when R_btn(0) = '1' else '0';
    gn13 <= '1' when R_btn(0) = '1' else '0'; -- eth- hotplug
    reset <= not R_btn(0);
--  If pll is not locked connect blink to PLL block     
    reset_pll <= reset when locked = '1' else reset_pll_blink;

    
    -- connect output to monitor Second PMOD on RIGHT BOTTOM
    -- not should show picture with all colors inverted
    --gp(15) <= not gpa(12);
    --gp(16) <= not gpa(11);
    --gp(17) <= not gpa(10);
    --gp(18) <= not gpa(9);

    clk_video_inst: entity work.ecp5pll
    generic map
    (
        in_Hz => natural( 25.0e6),
      out0_Hz => natural(100.0e6),                  out0_tol_hz => 0,
      out1_Hz => natural(125.0e6), out1_deg =>   0, out1_tol_hz => 0,
      out2_Hz => natural( 25.0e6), out2_deg =>   0, out2_tol_hz => 0,
      reset_en   => 1,
      dynamic_en => 1
    )
    port map
    (
      clk_i        => gpa(12),  -- normal
      --clk_i        => clk_25mhz, -- debug
      phasesel     => phasesel, -- output2 "10"-clk_pixel, output1 "01"-clk_shift
      phasedir     => R_btn(1),
      phasestep    => R_btn(3), -- need debounce
      phaseloadreg => '0',      -- need debounce
      locked       => locked,
      reset        => reset_pll,
      clk_o        => clocks
    );
    clk_100   <= clocks(0); -- not used
    clk_shift <= clocks(1);
    clk_pixel <= clocks(2);

    -- hold btn3 for fine selection
    phasesel <= "01" when R_btn(2)='1' else "10";
    --phasesel <= "10"; -- adjust clk_pixel
    --phasesel <= "01"; -- adjust clk_shift

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
    -- H-V sync ready for output
    led(5) <= vga_hsync;
    led(4) <= vga_vsync;
    -- blue color data
    --led(2 downto 0) <= vga_blue(2 downto 0);

    g_vga_out: if c_vga_out = 1 generate
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
    end generate;

    i_edid_rom: entity work.edid_rom
    port map
    (
             clk        => clk_25mhz,
             sclk_raw   => gn8,
             sdat_raw   => gpb(8),
             edid_debug => open
    );

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

    -- BTN:
    -- DIR RESET       CLK
    --           GREEN RED BLUE
    g_delay: for i in 0 to 2 generate
      input_delay : DELAYF
      port map (A => gpa(9+i), Z => input_delayed(i), LOADN => R_btn(0), MOVE => R_btn(6-i), DIRECTION => R_btn(1), CFLAG => S_delay_limit(i));
      led(i) <= S_delay_limit(i);
    end generate;
    input_delayed(3) <= gpa(12); -- no delay for clock. PLL controls phase shift instead of delay

    g_sdr_in: if c_bits = 1 generate
      tmds_c_i(0) <= input_delayed(3);
      tmds_r_i(0) <= input_delayed(2);
      tmds_g_i(0) <= input_delayed(1);
      tmds_b_i(0) <= input_delayed(0);
    end generate;

    g_ddr_in: if c_bits = 2 generate
    input_clock : IDDRX1F
    port map (D => input_delayed(3), Q0 => tmds_c_i(0), Q1 => tmds_c_i(1), SCLK => clk_shift, RST => '0');
    input_red   : IDDRX1F
    port map (D => input_delayed(2), Q0 => tmds_r_i(0), Q1 => tmds_r_i(1), SCLK => clk_shift, RST => '0');
    input_green : IDDRX1F
    port map (D => input_delayed(1), Q0 => tmds_g_i(0), Q1 => tmds_g_i(1), SCLK => clk_shift, RST => '0');
    input_blue  : IDDRX1F
    port map (D => input_delayed(0), Q0 => tmds_b_i(0), Q1 => tmds_b_i(1), SCLK => clk_shift, RST => '0');
    end generate;

    -- deserialize tmds_p to parallel 10-bit
    -- clk_pixel and clk_shift must be phase aligned with tmds_p(3) clock
    tmds_deserializer_inst: entity work.tmds_deserializer
    generic map
    (
      c_input_bits  => c_bits,
      c_latch_phase => 0
    )
    port map
    (
      clk_pixel => clk_pixel,
      clk_shift => clk_shift,
      c_i       => tmds_c_i,
      r_i       => tmds_r_i,
      g_i       => tmds_g_i,
      b_i       => tmds_b_i,
      r_o       => des_red,
      g_o       => des_green,
      b_o       => des_blue
    );

    tmds_serializer_red_inst: entity work.serialiser_10_to_x
    generic map
    (
      c_output_bits => c_bits
    )
    port map
    (
      clk    => clk_pixel,
      clk_x  => clk_shift,
      reset  => '0',
      data   => des_red,
      serial => tmds_r_o
    );

    tmds_serializer_green_inst: entity work.serialiser_10_to_x
    generic map
    (
      c_output_bits => c_bits
    )
    port map
    (
      clk    => clk_pixel,
      clk_x  => clk_shift,
      reset  => '0',
      data   => des_green,
      serial => tmds_g_o
    );

    tmds_serializer_blue_inst: entity work.serialiser_10_to_x
    generic map
    (
      c_output_bits => c_bits
    )
    port map
    (
      clk    => clk_pixel,
      clk_x  => clk_shift,
      reset  => '0',
      data   => des_blue,
      serial => tmds_b_o
    );

    g_yes_bypass: if c_dvi2vga_bypass = 1 generate
    g_sdr_out: if c_bits = 1 generate
      gpdi_dp(3) <= clk_pixel;
      gpdi_dp(2) <= tmds_r_o(0);
      gpdi_dp(1) <= tmds_g_o(0);
      gpdi_dp(0) <= tmds_b_o(0);
    end generate;

    g_ddr_out: if c_bits = 2 generate
      gpdi_dp(3) <= clk_pixel;
      --output_clock : ODDRX1F
      --port map (D0 => tmds_c_o(0), D1 => tmds_c_o(1), Q => gpdi_dp(3), SCLK => clk_shift, RST => '0');
      output_red   : ODDRX1F
      port map (D0 => tmds_r_o(0), D1 => tmds_r_o(1), Q => gpdi_dp(2), SCLK => clk_shift, RST => '0');
      output_green : ODDRX1F
      port map (D0 => tmds_g_o(0), D1 => tmds_g_o(1), Q => gpdi_dp(1), SCLK => clk_shift, RST => '0');
      output_blue  : ODDRX1F
      port map (D0 => tmds_b_o(0), D1 => tmds_b_o(1), Q => gpdi_dp(0), SCLK => clk_shift, RST => '0');
    end generate;
    end generate;
    
    b_hex_lcd: block
      constant c_color_bits: natural := 16;
      signal x,y: std_logic_vector(7 downto 0);
      signal color, R_color: std_logic_vector(c_color_bits-1 downto 0);
      signal R_display: std_logic_vector(127 downto 0);
      signal w_oled_csn: std_logic;
      signal next_pixel: std_logic;
    begin
      -- counter tracker for 3 DELAY lines
      g_delay_tracker: for i in 0 to 2 generate
      process(clk_25mhz)
      begin
        if rising_edge(clk_25mhz) then
          if reset = '1' then
            R_display(6+8*i downto 8*i) <= (others => '0');
          else
            if R_btn_prev /= R_btn then
              if R_btn(6-i)='1' then
                if R_btn(1)='1' then -- going reverse
                  if S_delay_limit(i)='1' then
                    R_display(6+8*i downto 8*i) <= (others => '0');
                  else
                    R_display(6+8*i downto 8*i) <= R_display(6+8*i downto 8*i)-1;
                  end if;
                else -- going forward
                  if S_delay_limit(i)='1' then
                    R_display(6+8*i downto 8*i) <= (others => '1');
                  else
                    R_display(6+8*i downto 8*i) <= R_display(6+8*i downto 8*i)+1;
                  end if;
                end if;
              end if;
            end if;
          end if;
        end if;
      end process;
      end generate;
      -- counter tracker for 2 PLL channels
      g_pll_tracker: for i in 0 to 1 generate
      process(clk_25mhz)
      begin
        if rising_edge(clk_25mhz) then
          if reset = '1' then
            R_display(6+8*i+24 downto 8*i+24) <= (others => '0');
          else
            if R_btn_prev /= R_btn then
              if R_btn(3)='1' and ((i=0 and R_btn(2)='0') or (i=1 and R_btn(2)='1')) then
                if R_btn(1)='1' then -- going reverse
                    R_display(6+8*i+24 downto 8*i+24) <= R_display(6+8*i+24 downto 8*i+24)-1;
                else -- going forward
                    R_display(6+8*i+24 downto 8*i+24) <= R_display(6+8*i+24 downto 8*i+24)+1;
                end if;
              end if;
            end if;
          end if;
        end if;
      end process;
      end generate;
    
      hex_decoder_inst: entity work.hex_decoder
      generic map
      (
        c_data_len   => 128,
        c_row_bits   => 4,
        c_grid_6x8   => 1,
        c_font_file  => "hex_font.mem",
        c_color_bits => c_color_bits
      )
      port map
      (
        clk  => clk_25mhz,
        data => R_display,
        x => x(7 downto 1),
        y => y(7 downto 1),
        color => color
      );

      -- allow large combinatorial logic
      -- to calculate color(x,y)
      process(clk_25mhz)
      begin
        if rising_edge(clk_25mhz) then
          if next_pixel = '1' then
            R_color <= color;
          end if;
        end if;
      end process;
      
      lcd_video_inst: entity work.lcd_video_vhd
      generic map
      (
        c_clk_mhz      => 25,
        c_init_file    => "st7789_linit_xflip.mem",
        c_init_size    => 38,
        c_clk_phase    => 0,
        c_clk_polarity => 1
      )
      port map
      (
        clk            => clk_25mhz,
        clk_pixel_ena  => '1',
        reset          => reset,
        x              => x,
        y              => y,
        blank          => '0',
        hsync          => '1',
        vsync          => '1',
        next_pixel     => next_pixel,
        color          => R_color,
        spi_clk        => oled_clk,
        spi_mosi       => oled_mosi,
        spi_dc         => oled_dc,
        spi_resn       => oled_resn,
        spi_csn        => w_oled_csn
      );
      oled_csn <= '1';
    end block;

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
    generic map
    (
      c_ddr     => '1' -- '0' for c_bits=1, '1' for c_bits=2
    )
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

    g_not_bypass: if c_dvi2vga_bypass = 0 generate
    g_sdr_out: if c_bits = 1 generate
      gpdi_dp(3) <= clk_pixel;
      gpdi_dp(2) <= fin_red(0);
      gpdi_dp(1) <= fin_green(0);
      gpdi_dp(0) <= fin_blue(0);
    end generate;

    g_ddr_out: if c_bits = 2 generate
      --gpdi_dp(3) <= clk_pixel;
      output_clock : ODDRX1F
      port map (D0 => fin_clock(0), D1 => fin_clock(1), Q => gpdi_dp(3), SCLK => clk_shift, RST => '0');
      output_red   : ODDRX1F
      port map (D0 => fin_red(0),   D1 => fin_red(1),   Q => gpdi_dp(2), SCLK => clk_shift, RST => '0');
      output_green : ODDRX1F
      port map (D0 => fin_green(0), D1 => fin_green(1), Q => gpdi_dp(1), SCLK => clk_shift, RST => '0');
      output_blue  : ODDRX1F
      port map (D0 => fin_blue(0),  D1 => fin_blue(1),  Q => gpdi_dp(0), SCLK => clk_shift, RST => '0');
    end generate;
    end generate;

end Behavioral;
