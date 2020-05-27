-- (c)EMARD
-- License=BSD

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library ecp5u;
use ecp5u.components.all;

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
    led       : out std_logic_vector(7 downto 0)
  );
end;

architecture mix of top_lvds_passthru is
    type T_blink is array (0 to 3) of std_logic_vector(bits-1 downto 0);
    type T_pixel is array (3 downto 0) of std_logic_vector(6 downto 0);
    signal R_blink: T_blink;
    signal clocks: std_logic_vector(3 downto 0);
    alias clk_pixel: std_logic is clocks(1);
    alias clk_shift: std_Logic is clocks(2);
    signal R_btn_prev, R_btn_latch, R_btn: std_logic_vector(6 downto 0);
    signal R_btn_debounce: std_logic_vector(19 downto 0);
    signal input_delayed: std_logic_vector(3 downto 0);
    signal S_delay_limit: std_logic_vector(3 downto 0);
    signal R_lvds, R_pixel: T_pixel;
    signal vga_r, vga_g, vga_b: std_logic_vector(5 downto 0);
    signal vga_hsync, vga_vsync, vga_de: std_logic;
begin
    clkgen_inst: entity work.clkgen
    generic map
    (
        in_hz    => natural( 10.0e6),
      out0_hz    => natural( 70.0e6),
      out1_hz    => natural( 10.0e6), -- clk_pixel
      out1_deg   =>           0,      -- 0-30, 340-359
      out2_hz    => natural( 70.0e6), -- clk_shift
      out2_deg   =>         100,      -- 100 is ok, 40-150
      out3_hz    => natural( 70.0e6),
      out3_deg   =>           0,
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
    
--    G_read_bits: for i in 0 to 3 generate
--    process(clk_shift)
--    begin
--      if rising_edge(clk_shift)
--      then
--        R_lvds(i) <= gp_i(9+i) & R_lvds(i)(6 downto 1);
--      end if;
--    end process;
--    process(clk_pixel)
--    begin
--      if rising_edge(clk_pixel)
--      then
--        R_pixel(i) <= R_lvds(i);
--      end if;
--    end process;
--    end generate;
    --gp_o(3) <= R_lvds(0)(0); -- red
    --gp_o(4) <= R_lvds(1)(0); -- green
    --gp_o(5) <= R_lvds(2)(0); -- blue and sync
    --gp_o(6) <= R_lvds(3)(0); -- clock

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
      --r_i    => vga_r;
      r_i     => (others => '0'), -- red OFF (hardware bug with red channel)
      g_i     => vga_g,
      b_i     => vga_b,
      hsync_i => vga_hsync,
      vsync_i => vga_vsync,
      de_i    => vga_de,
      lvds_o  => gp_o(6 downto 3)
    );

end mix;
