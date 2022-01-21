-- FM transmitter
-- (c) Marko Zec
-- LICENSE=BSD

-- This module can be used for any FM range

-- when used with FM RADIO 87-108 kHz
-- maximum frequency deviation is 75 kHz
-- input pcm value has range -32767..+32767
-- and corresponds to frequency deviation
-- of 2x pcm value -65536 .. +65536 Hz

library IEEE;
use IEEE.std_logic_1164.all;
-- use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity fmgen is
generic (
    c_use_pcm_in: boolean := true;
    c_fm_acclen: integer range 27 to 29 := 28; -- phase accumulator length, max 28 or 29 depends on c_fdds
    -- modulation: how many Hz CW will swing when input changes by 1:
    -- by FM standard, max CW swing is 75 kHz. Channels are 100 kHz apart.
    -- 16-bit signed input values have full range in -32767..+32767, for
    -- 1Hz/bit can make max 65 kHz swing and assures no overmodulation.
    -- 2Hz/bit (default) allows full use of 75 kHz band swing but input value must
    -- stay in range -18750..+18750 to prevent overmodulation.
    -- When changing c_2n_hz_per_bit,
    -- other RDS and pilot tone values must be scaled in rds.vhd
    c_2n_hz_per_bit:  integer range 0 to  2 := 1; -- 2**n Hz FM modulation strength 0:1, 1:2 (default), 2:4 Hz/bit
    c_remove_dc_bits: integer range 0 to 16 := 5; -- DC bias update every 2**n+1 PCM clock, 0 to disable
    c_fdds: real -- Hz input clock frequency e.g. 250000000.0
);
port (
    clk_pcm: in std_logic; -- PCM processing clock, any (e.g. 25 MHz)
    clk_dds: in std_logic; -- DDS clock must be >2*cw_freq (e.g. 250 MHz)
    cw_freq: in std_logic_vector(31 downto 0);
    pcm_in: in signed(15 downto 0); -- FM swing: pcm_in * hz_per_bit
    fm_out: out std_logic
);
end fmgen;

architecture x of fmgen is
    signal fm_acc, fm_inc: unsigned(C_fm_acclen-1 downto 0);
    signal R_pcm_avg, R_pcm_ac: signed(15 downto 0);
    signal R_cnt: integer;
    signal R_dds_mul_x1, R_dds_mul_x2: unsigned(31 downto 0);
    constant c_fpp_bits: integer := 30; -- fixed point precision extra bits
    constant C_dds_mul_y: unsigned(31 downto 0) :=
        to_unsigned(integer(2.0**(c_fpp_bits+c_fm_acclen) / C_fdds + 0.5), 32);
    signal R_dds_mul_res: unsigned(63 downto 0);
    signal R_clk_div: unsigned(c_remove_dc_bits downto 0);
    signal s_cw_freq: signed(cw_freq'range);
begin
    -- Calculate signal average to remove DC bias
    yes_remove_dc_bias: if c_remove_dc_bits > 0 generate
    process(clk_pcm)
    begin
        if rising_edge(clk_pcm) then
            R_pcm_ac <= pcm_in - R_pcm_avg; -- subtract average to remove DC offset
	    if R_clk_div(c_remove_dc_bits) = '1' then
		if R_pcm_ac > 0 then
		    R_pcm_avg <= R_pcm_avg + 1;
		elsif R_pcm_ac < 0 then
		    R_pcm_avg <= R_pcm_avg - 1;
		end if;
		R_clk_div <= (others => '0');
	    else
	        R_clk_div <= R_clk_div + 1;
	    end if;
        end if;
    end process;
    end generate;

    not_remove_dc_bias: if c_remove_dc_bits = 0 generate
    process(clk_pcm)
    begin
        if rising_edge(clk_pcm) then
            R_pcm_ac <= pcm_in;
        end if;
    end process;
    end generate;

    --
    -- Calculate current frequency of carrier wave (Frequency modulation)
    -- Removing DC offset
    --
    s_cw_freq <= signed(cw_freq);
    process (clk_pcm)
    begin
	if (rising_edge(clk_pcm)) then
            -- R_dds_mul_x1 <= cw_freq + R_pcm_ac * 2**c_2n_hz_per_bit
	    R_dds_mul_x1 <= unsigned((s_cw_freq(s_cw_freq'length-1 downto c_2n_hz_per_bit) + R_pcm_ac(R_pcm_ac'length-1 downto c_2n_hz_per_bit))
	                  &           s_cw_freq(c_2n_hz_per_bit-1 downto 0) ); -- padding
	end if;
    end process;
	
    --
    -- Generate carrier wave
    --
    process (clk_dds)
    begin
	if (rising_edge(clk_dds)) then
	    -- Cross clock domains
            R_dds_mul_x2  <= R_dds_mul_x1;
            R_dds_mul_res <= C_dds_mul_y * R_dds_mul_x2;
            fm_inc <= R_dds_mul_res(c_fm_acclen+c_fpp_bits-1 downto c_fpp_bits);
            fm_acc <= fm_acc + fm_inc;
	end if;
    end process;

    fm_out <= fm_acc((C_fm_acclen - 1));
end;
