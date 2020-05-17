-- -----------------------------------------------------------------------------
-- Copyright (c) 2013 Benjamin Krill <benjamin@krll.de>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
-- -----------------------------------------------------------------------------

-- Code cutoff by Emard

-- see http://www.cs.unc.edu/~stc/FAQs/Video/dvi_spec-V1_0.pdf

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tmds_dekoder is
port
(
	clk   : in  std_logic; -- pixel clock
	din   : in  std_logic_vector(9 downto 0); -- input 10-bit tmds encoded data
	dout  : out std_logic_vector(7 downto 0); -- output 8-bit decoded data
	c     : out std_logic_vector(1 downto 0); -- control signals, blue channel c(1)=vsync c(0)=hsync
	blank : out std_logic -- blank = not de (display enable)
);
end;

architecture decoder of tmds_dekoder is
        constant C_CTRL0  : std_logic_vector(9 downto 0) := "1101010100";
        constant C_CTRL1  : std_logic_vector(9 downto 0) := "0010101011";
        constant C_CTRL2  : std_logic_vector(9 downto 0) := "0101010100";
        constant C_CTRL3  : std_logic_vector(9 downto 0) := "1010101011";
	signal R_dout     : std_logic_vector(7 downto 0);
	signal S_dout     : std_logic_vector(7 downto 0);
	signal S_data     : std_logic_vector(7 downto 0);
	signal R_c        : std_logic_vector(1 downto 0);
	signal R_blank    : std_logic;
begin
	-- ----------------------------------------------------------
	-- performs the 10->8 bit decoding function defined in DVI 1.0
	-- Specification: Section 3.3.3, Figure 3-6, page 31.
	-- ----------------------------------------------------------
	S_data <= not din(7 downto 0) when din(9) = '1' else din(7 downto 0);
	S_dout(0) <= S_data(0);
	G_tmds_decoder:
	for i in 0 to 6 generate
		S_dout(i+1) <= S_data(i+1) xor S_data(i) when din(8) = '1' else S_data(i+1) xnor S_data(i);
	end generate;

	process (clk)
	begin
	if rising_edge(clk) then
		case din is
		when C_CTRL0 =>
			R_c <= "00"; R_blank <= '1';
		when C_CTRL1 =>
			R_c <= "01"; R_blank <= '1';
		when C_CTRL2 =>
			R_c <= "10"; R_blank <= '1';
		when C_CTRL3 =>
			R_c <= "11"; R_blank <= '1';
		when others =>
			R_dout <= S_dout; R_blank <= '0';
		end case;
	end if;
	end process;

	c     <= R_c;
	blank <= R_blank;
	dout  <= R_dout;
end decoder;
