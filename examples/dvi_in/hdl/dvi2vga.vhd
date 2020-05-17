library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity dvi2vga is
Port
( 
  clk: in std_logic; -- pixel clock
  dvi_red, dvi_green, dvi_blue: in std_logic_vector(9 downto 0); -- 10-bit TMDS encoded
  vga_red, vga_green, vga_blue: out std_logic_vector(7 downto 0); -- 8-bit RGB color decoded
  vga_hsync, vga_vsync, vga_blank: out std_logic -- frame control
);
end;

architecture Behavioral of dvi2vga is
begin

    red_decoder_inst:
    entity work.tmds_dekoder
    port map
    (
      clk => clk,
      din => dvi_red,
      dout => vga_red
    );

    green_decoder_inst:
    entity work.tmds_dekoder
    port map
    (
      clk => clk,
      din => dvi_green,
      dout => vga_green
    );

    blue_decoder_inst:
    entity work.tmds_dekoder
    port map
    (
      clk => clk,
      din => dvi_blue,
      dout => vga_blue,
      c(1) => vga_vsync,
      c(0) => vga_hsync,
      blank => vga_blank
    );

end Behavioral;
