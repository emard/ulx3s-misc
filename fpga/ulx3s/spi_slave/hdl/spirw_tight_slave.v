// SPI RW slave

// AUTHOR=EMARD
// LICENSE=BSD

// right timing without dummy bytes, core is complex

// write 00 <MSB_addr> <LSB_addr> <byte0> <byte1>
// read  01 <MSB_addr> <LSB_addr> <byte0> <byte1>

module spirw_slave
#(
  parameter C_sclk_capable_pin = 1'b0, // 0-sclk is generic pin, 1-sclk is clock capable pin
  parameter C_data_len = 8 // don't touch, data bit length, currently 8 only
)
(
  input  wire clk, // faster than SPI clock
  input  wire sclk, mosi, csn, // SPI lines to be sniffed
  inout  wire miso, // 3-state line, active when csn=0
  output wire we,
  output wire [15:0] addr,
  input  wire [C_data_len-1:0] data_in,
  output reg  [C_data_len-1:0] data_out // continuously shifted
);
  wire R_request_read, R_request_read2;
  wire R_request_write;
  reg [5:0] R_bit_count;
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
      reg [16:0] R_raddr;
      reg [15:0] R_addr;
      reg [C_data_len-1:0] R_MISO, R_MOSI;
      always @(posedge clk)
      begin
        R_sclk <= {R_sclk[0], sclk};
        R_mosi <= mosi;
      end
      always @(posedge clk)
      begin
        if(csn == 1'b0)
        begin
          if(R_sclk == 2'b01) // rising edge
          begin
            R_MOSI <= { R_MOSI[C_data_len-2:0], R_mosi };
            R_MISO <= { R_MISO[C_data_len-2:0], R_MISO[C_data_len-1] };
            if(R_bit_count[2:0] == 3'd0)
            begin
              R_request_read <= 1'b1;
            end
            if(R_bit_count[5] == 1'b0) // first 3 bytes
            begin
              R_raddr <= { R_raddr[15:0], R_mosi };
              R_bit_count <= R_bit_count - 1;
            end
            else // after first 3 bytes
            begin
              if(R_raddr[16])
              begin // read
                if(R_bit_count[2:0] == 3'd3)
                begin
                  R_raddr[15:0] <= R_raddr[15:0] + 1;
                end
              end
              else
              begin // write
                if(R_bit_count[3:0] == 4'd3) // first time don't increment address
                begin
                  R_raddr[15:0] <= R_raddr[15:0] + 1;
                end
                if(R_bit_count[2:0] == 3'd0) // last bit in byte -> write
                begin
                  R_request_write <= 1'b1;
                  data_out <= { R_MOSI[C_data_len-2:0], R_mosi };
                end
              end 
              if(R_bit_count[2:0] == 3'd0)
                R_bit_count[3] <= 1'b0; // reset first time indicator bit
              R_bit_count[2:0] <= R_bit_count[2:0] - 1;
            end
          end
          else // not rising edge
          begin
            if(R_request_read2 == 1'b1)
            begin
              R_MISO <= data_in;
            end
            R_request_read2 <= R_request_read;
            R_request_read <= 1'b0;
            R_request_write <= 1'b0;
          end
        end
        else
          R_bit_count <= 6'd23; // 24 bits = 3 bytes to read
      end
    end
  endgenerate
  assign we   = R_request_write;
  assign addr = R_raddr[15:0];
  assign miso = csn ? 1'bz : R_MISO[C_data_len-1];
endmodule
