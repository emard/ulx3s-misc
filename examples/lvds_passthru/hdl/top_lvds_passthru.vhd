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
begin
    clkgen_inst: entity work.clkgen
    generic map
    (
        in_hz    => natural( 10.0e6),
      out0_hz    => natural( 70.0e6),
      out1_hz    => natural( 10.0e6), -- clk_pixel
      out1_deg   =>           0,
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

    -- BTN:
    -- DIR RESET       CLK
    --           GREEN RED BLUE
    --g_delay: for i in 0 to 2 generate
    --  input_delay : DELAYF
    --  port map (A => gp_i(9+i), Z => input_delayed(i), LOADN => R_btn(0), MOVE => R_btn(6-i), DIRECTION => R_btn(1), CFLAG => S_delay_limit(i));
    --  led(i) <= S_delay_limit(i);
    --end generate;
    --input_delayed(3) <= gp_i(12); -- no delay for clock. PLL controls phase shift instead of delay

    --gn(7 downto 0) <= (others => '0');
    --gp(7 downto 0) <= (others => '0');
    gn(8) <= '1'; -- normally PWM
    
    G_read_bits: for i in 0 to 3 generate
    process(clk_shift)
    begin
      if rising_edge(clk_shift)
      then
        R_lvds(i) <= gp_i(9+i) & R_lvds(i)(6 downto 1);
      end if;
    end process;
    process(clk_pixel)
    begin
      if rising_edge(clk_pixel)
      then
        R_pixel(i) <= R_lvds(i);
      end if;
    end process;
    end generate;
    --gp_o(3) <= R_lvds(0)(0); -- red
    --gp_o(4) <= R_lvds(1)(0); -- green
    --gp_o(5) <= R_lvds(2)(0); -- blue and sync
    --gp_o(6) <= R_lvds(3)(0); -- clock

    vga2lvds_inst: entity work.vga2lvds
    port map
    (
      clk_pixel => clk_pixel,
      clk_shift => clk_shift,
      --in_red    => R_pixel(0)(1)&R_pixel(0)(2)&R_pixel(0)(3)&R_pixel(0)(4)&R_pixel(0)(5)&R_pixel(0)(6)&"00",
      in_red    => (others => '0'), -- red OFF (hardware bug with red channel)
      in_green  => R_pixel(1)(2)&R_pixel(1)(3)&R_pixel(1)(4)&R_pixel(1)(5)&R_pixel(1)(6)&R_pixel(0)(1)&"00",
      in_blue   => R_pixel(2)(3)&R_pixel(2)(4)&R_pixel(2)(5)&R_pixel(2)(6)&R_pixel(1)(0)&R_pixel(1)(1)&"00",
      in_hsync  => R_pixel(2)(2),
      in_vsync  => R_pixel(2)(1),
      in_blank  => not R_pixel(2)(0),
      out_lvds  => gp_o(6 downto 3)
    );

end mix;
