-- VHDL wrapper for spirw_slave_v.v

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity spi_ram_btn is
  generic
  (
    --c_addr_floppy      : std_logic_vector(7 downto 0) := x"D0"; -- high addr byte of floppy req type
    c_addr_btn         : std_logic_vector(7 downto 0) := x"FB"; -- addr byte of BTNs
    c_addr_irq         : std_logic_vector(7 downto 0) := x"F1"; -- high addr byte of IRQ flag
    c_debounce_bits    : natural := 20; -- more -> slower BTNs
    c_addr_bits        : natural := 32; -- don't touch
    c_sclk_capable_pin : natural := 0 -- 0-sclk is generic pin, 1-sclk is clock capable pin
  );
  port
  (
    clk             : in    std_logic;
    csn, sclk, mosi : in    std_logic;
    miso            : inout std_logic;
    btn             : in    std_logic_vector(6 downto 0);
    irq             : out   std_logic;
    --floppy_req_type : in    std_logic_vector(7 downto 0) := (others => '0');
    --floppy_req      : in    std_logic := '0';
    --floppy_in_drive : in    std_logic_vector(1 downto 0) := (others => '0'); -- future expansion
    rd, wr          : out   std_logic;
    addr            : out   std_logic_vector(c_addr_bits-1 downto 0);
    data_in         : in    std_logic_vector(7 downto 0);
    data_out        : out   std_logic_vector(7 downto 0)
  );
end;

architecture syn of spi_ram_btn is
  component spi_ram_btn_v -- verilog name and its parameters
  generic
  (
    --c_addr_floppy      : std_logic_vector(7 downto 0);
    c_addr_btn         : std_logic_vector(7 downto 0);
    c_addr_irq         : std_logic_vector(7 downto 0);
    c_debounce_bits    : natural;
    c_addr_bits        : natural;
    c_sclk_capable_pin : natural
  );
  port
  (
    clk             : in    std_logic;
    csn, sclk, mosi : in    std_logic;
    miso            : inout std_logic;
    btn             : in    std_logic_vector(6 downto 0);
    irq             : out   std_logic;
    --floppy_req_type : in    std_logic_vector(7 downto 0);
    --floppy_req      : in    std_logic;
    --floppy_in_drive : in    std_logic_vector(1 downto 0);
    rd, wr          : out   std_logic;
    addr            : out   std_logic_vector(c_addr_bits-1 downto 0);
    data_in         : in    std_logic_vector(7 downto 0);
    data_out        : out   std_logic_vector(7 downto 0)
  );
  end component;

begin
  spi_ram_btn_v_inst: spi_ram_btn_v
  generic map
  (
    --c_addr_floppy      => c_addr_floppy,
    c_addr_btn         => c_addr_btn,
    c_addr_irq         => c_addr_irq,
    c_debounce_bits    => c_debounce_bits,
    c_addr_bits        => c_addr_bits,
    c_sclk_capable_pin => c_sclk_capable_pin
  )
  port map
  (
    clk => clk,              
    csn => csn, sclk => sclk, mosi => mosi,
    miso => miso,
    btn => btn,
    irq => irq,
    --floppy_req_type => floppy_req_type,
    --floppy_req      => floppy_req,
    --floppy_in_drive => floppy_in_drive,
    rd => rd, wr => wr,
    addr => addr,
    data_in => data_in,
    data_out => data_out
  );
end syn;
