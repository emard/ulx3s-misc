// SPI OLED SSD1331 display HEX decoder core
// AUTHOR=EMARD
// LICENSE=BSD

// SPI or JTAG sniffer

module spi_slave
#(
  parameter C_data_len = 8 // input bits data length
)
(
  input  wire clk, // SPI clk
  input  wire mosi, csn, // spi lines to be sniffed
  output reg  [C_data_len-1:0] data // continuously shifted
);
  always @(posedge clk)
  begin
    if(csn == 1'b0)
      data <= { data[C_data_len-2:0], mosi };
  end
endmodule
