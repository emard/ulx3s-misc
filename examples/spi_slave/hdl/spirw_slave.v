// SPI RW slave

// AUTHOR=EMARD
// LICENSE=BSD

module spirw_slave
#(
  parameter C_sclk_capable_pin = 1'b0, // 0-sclk is generic pin, 1-sclk is clock capable pin
  parameter C_data_len = 8 // input bits data length
)
(
  input  wire clk, // faster than SPI clock
  input  wire sclk, mosi, csn, // SPI lines to be sniffed
  inout  wire miso, // 3-state line, active when csn=0
  input  wire [C_data_len-1:0] data_in,
  output reg  [C_data_len-1:0] data_out // continuously shifted
);
  generate
    if(C_sclk_capable_pin)
    begin
      // sclk is clock capable pin
      always @(posedge sclk)
      begin
        if(csn == 1'b0)
          data_out <= { data_out[C_data_len-2:0], mosi };
      end
    end
    else
    begin
      // sclk is generic pin
      // it needs clock synchronous edge detection
      reg R_mosi;
      reg [1:0] R_sclk;
      always @(posedge clk)
      begin
        R_sclk <= {R_sclk[0], sclk};
        R_mosi <= mosi;
      end
      always @(posedge clk)
      begin
        if(csn == 1'b0)
          if(R_sclk == 2'b01) // rising edge
            data_out <= { data_out[C_data_len-2:0], R_mosi };
      end
    end
  endgenerate
endmodule
