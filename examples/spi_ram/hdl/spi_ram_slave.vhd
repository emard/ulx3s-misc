-------------------------------------------------------------------------------
--
-- SPI RAM slave
--
-- AUTHOR=EMARD
-- LICENSE=BSD
--
-- see also:
-- http://ww1.microchip.com/downloads/en/devicedoc/22100e.pdf
-- http://svn.navi.cx/misc/trunk/nds/spi-mem-emulator/
--
-- SPI:
-- 0x00 <16-bit addr MSB first> <bytes> -> write while csn=0
-- 0x01 <16-bit-addr MSB first> <dummy> <bytes> -> read while csn=0
--
-- CLK: low when inactive csn=1,
-- data change at falling clk edge
-- data stable at rising clk edge
--
-- this SPI RAM core differs from hardware SPI RAM
-- at read
-- SPI RAM core needs to read and discard first byte, then the data follow
-- SPI RAM chip immediately returns data, no dummy byte to read
-- TODO: fix dummy read byte
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_ram_slave is
  generic
  (
    C_dummy        : natural := 1
  );
  port
  (
    -- System Interface -------------------------------------------------------
    clk            : in    std_logic;     -- System clock
    -- SPI slave Interface ----------------------------------------------------
    csn            : in    std_logic;     -- slave chip select
    sclk           : in    std_logic;     -- SPI clock
    mosi           : in    std_logic;     -- Data from ESP32 (master out slave in)
    miso           : inout std_logic;     -- Data to ESP32 (master in slave out)
    -- BRAM interface
    ram_we         : out   std_logic;     -- 1:write 0:read
    ram_addr       : out   std_logic_vector(15 downto 0);
    ram_do         : out   std_logic_vector(7 downto 0);
    ram_di         : in    std_logic_vector(7 downto 0)
  );
end;

architecture rtl of spi_ram_slave is
  signal R_MISO_shift, R_MOSI_shift, S_MISO_shift_next: std_logic_vector(7 downto 0);
  signal R_SCLK_shift : std_logic_vector(1 downto 0);
  signal R_bit_counter: unsigned(2 downto 0);
  signal R_full_byte: std_logic;
  signal R_state: unsigned(1 downto 0); -- 0:expect CMD, 1:expect MSB addr, 2:expect LSB addr, 3:expect data
  signal R_we: std_logic;
  signal R_ram_we: std_logic;
  signal R_ram_do : std_logic_vector(7 downto 0);
  signal R_ram_addr: unsigned(ram_addr'range);
  signal R_ram_inc: std_logic; -- 1:increment RAM address
begin
  -- SPI clock Edge detection shift right and track change detection
  P_SCLK_shift_tracker: process(clk)
  begin
    if rising_edge(clk) then
      R_SCLK_shift <= SCLK & R_SCLK_shift(1);
    end if;
  end process P_SCLK_shift_tracker;

  S_MISO_shift_next <= R_MISO_shift(R_MISO_shift'high-1 downto 0) & R_MISO_shift(R_MISO_shift'high);
  P_SPI_slave: process(clk)
  begin
    if rising_edge(clk) then
      if csn = '1' then -- csn = 1 resets state
        R_MISO_shift <= x"00";
        R_MOSI_shift <= x"00";
        R_bit_counter <= (others => '0');
      else
        case R_SCLK_shift is
          when "10" => -- SCLK rising edge, data stable
            R_MOSI_shift <= R_MOSI_shift(R_MOSI_shift'high-1 downto 0) & MOSI;
            R_full_byte <= '0';
          when "01" => -- SCLK falling edge, data change
            case R_bit_counter is
              when "111" =>
                R_MISO_shift <= ram_di; -- SPI read is always a RAM read
                R_full_byte <= '1';
              when others =>
                R_MISO_shift <= S_MISO_shift_next;
            end case;
            R_bit_counter <= R_bit_counter + 1;
          when others =>
            R_full_byte <= '0';
        end case; -- SCLK edge
      end if;
    end if;
  end process P_SPI_slave;

  P_RAM_state: process(clk)
  begin
    if rising_edge(clk) then
      if csn = '1' then
        R_state <= "00";
      else -- csn = '0'
        if R_full_byte = '1' then
          case R_state is
            when "00" => -- expect CMD
              R_we <= not R_MOSI_shift(0); -- MOSI(0)=1:read, MOSI(0)=0:write
              R_state <= R_state + 1;
            when "01" => -- expect MSB addr
              R_ram_addr(15 downto 8) <= R_MOSI_shift;
              R_state <= R_state + 1;
            when "10" => -- expect LSB addr
              R_ram_addr(7 downto 0) <= R_MOSI_shift;
              R_state <= R_state + 1;
            when others => -- expect read/write data
              R_ram_do <= R_MOSI_shift;
              R_ram_we <= R_we;
              R_ram_inc <= '1';
          end case;
        else -- not full byte
          if R_ram_inc = '1' then
            R_ram_addr <= R_ram_addr + 1;
          end if;
          R_ram_inc <= '0';
          R_ram_we <= '0';
        end if;
      end if; -- csn
    end if;
  end process P_RAM_state;

  MISO <= R_MISO_shift(R_MISO_shift'high) when csn = '0' else 'Z';
  ram_we <= R_ram_we;
  ram_do <= R_ram_do;
  ram_addr <= R_ram_addr;
end rtl;
