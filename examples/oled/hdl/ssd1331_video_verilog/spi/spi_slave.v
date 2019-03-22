// SPI OLED SSD1331 display HEX decoder core
// AUTHOR=EMARD
// LICENSE=BSD

// SPI or JTAG sniffer

module spi_slave
#(
  parameter C_sclk_capable_pin = 1'b0, // 0-sclk is generic pin, 1-sclk is clock capable pin
  parameter C_data_len = 8 // input bits data length
)
(
  input  wire clk, // faster than SPI clock
  input  wire sclk, mosi, csn, // spi lines to be sniffed
  output reg  [C_data_len-1:0] data // continuously shifted
);
  generate
    if(C_sclk_capable_pin)
    begin
      // sclk is clock capable pin
      always @(posedge sclk)
      begin
        if(csn == 1'b0)
          data <= { data[C_data_len-2:0], mosi };
      end
    end
    else
    begin
      // sclk is generic pin
      // it needs clock synchronous edge detection
      reg [1:0] R_sclk;
      always @(posedge clk)
        R_sclk <= {R_sclk[0], sclk};
      always @(posedge clk)
      begin
        if(csn == 1'b0)
          if(R_sclk == 2'b01) // rising edge
            data <= { data[C_data_len-2:0], mosi };
      end
    end
  endgenerate
endmodule
