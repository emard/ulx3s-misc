library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gray_counter is

  port 
  (
    clk        : in std_logic;
    reset      : in std_logic;
    enable     : in std_logic;
    gray_count : out std_logic_vector(7 downto 0)
  );

end entity;

-- Implementation:

-- There is an imaginary bit in the counter, at q(0), that resets to 1
-- (unlike the rest of the bits of the counter) and flips every clock cycle.
-- The decision of whether to flip any non-imaginary bit in the counter
-- depends solely on the bits below it, down to the imaginary bit.	It flips
-- only if all these bits, taken together, match the pattern 10* (a one
-- followed by any number of zeros).

-- Almost every non-imaginary bit has a component instance that sets the 
-- bit based on the values of the lower-order bits, as described above.
-- The rules have to differ slightly for the most significant bit or else 
-- the counter would saturate at it's highest value, 1000...0.

architecture rtl of gray_counter is

	-- q contains all the values of the counter, plus the imaginary bit
	-- (values are shifted to make room for the imaginary bit at q(0))
	signal q  : std_logic_vector (8 downto 0);

	-- no_ones_below(x) = 1 iff there are no 1's in q below q(x)
	signal no_ones_below  : std_logic_vector (8 downto 0);

	-- q_msb is a modification to make the msb logic work
	signal q_msb : std_logic;

begin

	q_msb <= q(7) or q(8);

	process(clk, reset, enable)
	begin

		if(reset = '1') then

			-- Resetting involves setting the imaginary bit to 1
			q(0) <= '1';
			q(8 downto 1) <= (others => '0');

		elsif(rising_edge(clk) and enable='1') then
		
			-- Toggle the imaginary bit
			q(0) <= not q(0);
			
			for i in 1 to 8 loop
			
				-- Flip q(i) if lower bits are a 1 followed by all 0's
				q(i) <= q(i) xor (q(i-1) and no_ones_below(i-1));
			
			end loop;  -- i
			
			q(8) <= q(8) xor (q_msb and no_ones_below(7));
			
		end if;
		
	end process;
	
	-- There are never any 1's beneath the lowest bit
	no_ones_below(0) <= '1';
	
	process(q, no_ones_below)
	begin
		for j in 1 to 8 loop
			no_ones_below(j) <= no_ones_below(j-1) and not q(j-1);
		end loop;
	end process;
	
	-- Copy over everything but the imaginary bit
	gray_count <= q(8 downto 1);
	
end rtl;
