// 8-bit interface to i2c master

// writing to byte addr=0 will initiate i2c read or write operation

// WRITE
// byte addr=3
//  31    1:read, 0:write.
//  30    Repeated Start.  On read cycles setting this bit uses repeated start instad of stop start sequence.
//  29:23 Reserved.
// byte addr=2
//  22:16 7-bit I2C address of slave.
// byte addr=11
//  15:8  Register Subaddress
// byte addr=0
//  7:0   Data to write.  Don't care on read cycles.

// READ
// byte addr=3
//  31    Busy.  Not ready to accept new control register writes.
//  30    Address NACK.  Last address cycle resulted in no acknowledge from slave.
//  29    Data NACK.  Last data write cycle resulted in no acknowledge from slave.
//  28    Read.  Most recently completed cycle was a read.  Data in bits 7:0 is valid.
//  27    Overrun.  An attempt was made to write the ctrl_reg while busy.  Cleared
//        on successful write of ctrl_reg.
//  26    Initializing - waiting for SDA to go high after module reset
//  25:24 Reserved.  Tied to zero.
// byte addr=2,1
//  23:8  Reserved.  Tied to zero.
// byte addr=0
//  7:0   Read data.  Valid after a read cycle when bit 28 is set.

`default_nettype none

module i2c_master_8bit
#(
  parameter c_clk_mhz = 25
)
(
  input  wire       clk,
  input  wire       reset,

  // retro CPU interface
  input  wire [1:0] addr, // 4-byte = 32-bit
  input  wire [7:0] di,
  output reg  [7:0] do,
  input  wire       csn,  // 0-select 1-not select
  input  wire       wrn,  // 0-write  1-not write
  input  wire       rdn,  // 0-read   1-not read

  // I2C to RTC chip
  inout  wire       sda,
  inout  wire       scl
);
  reg i2c_request;
  reg [7:0] r_request[0:3];
  always @(posedge clk)
  begin
    if (csn == 0 && wrn == 0) begin
      r_request[addr] <= di;
      if (addr == 0)
        i2c_request <= 1;
    end else begin
      i2c_request <= 0;
    end
  end
  wire [31:0] request = {r_request[3],r_request[2],r_request[1],r_request[0]};
  //wire [31:0] request = {8'h80,8'h6F,r_request[1],r_request[0]}; // DEBUG

  wire [31:0] response;
  wire  [7:0] w_response[0:3];
  assign w_response[3] = response[31:24];
  assign w_response[2] = response[23:16];
  assign w_response[1] = response[15:8];
  assign w_response[0] = response[7:0];
  always @(posedge clk)
  begin
    if (csn == 0 && rdn == 0) begin
      do <= w_response[addr];
    end
  end

  i2c_master
  #(
    .freq         (c_clk_mhz) // MHz
  )
  i2c_master_inst
  (
    .sys_clock    (clk),
    .reset        (reset),
    .wr_ctrl      (i2c_request),
    .ctrl_data    (request),
    .status       (response),
    .SDA          (sda),
    .SCL          (scl)
  );

endmodule
