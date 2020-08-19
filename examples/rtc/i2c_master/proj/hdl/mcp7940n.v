// reads current time from MCP7940N I2C RTC
// and provides 56-bit datetime BCD vector

// TODO schedule reading 0.5s before tick of a seconds
// all register reading cycle should be done
// during the safe interval when register don't change
// FIXME tick ticks as valid data not at each second

`default_nettype none

module mcp7940n
#(
  parameter c_clk_mhz   = 25, // MHz clk, i2c needs to know
  parameter c_slow_bits = 18  // 2^n slowdown to read each register 18->95 Hz at 25 MHz
)
(
  input  wire        clk,        // System clock, wr_ctrl should be synchronous to this
  input  wire        reset,      // 1:reset - puts I2C bus into idle state
  output reg         tick,       // ticks every second -> 1: datetime_o is valid
  output wire [55:0] datetime_o, // BCD {YY,MM,DD, WD, HH,MM,SS}
  //input  wire [55:0] datetime_i,  // future expansion
  inout  wire        sda,        // I2C Serial data line, pulled high at board level
  inout  wire        scl         // I2C Serial clock line, pulled high at board level
);

  wire [31:0] ctrl_data, status;
  wire wr_ctrl;
  i2c_master
  #(
    .freq         (c_clk_mhz) // MHz
  )
  i2c_master_inst
  (
    .sys_clock    (clk),
    .reset        (reset),
    .SDA          (sda),
    .SCL          (scl),
    .ctrl_data    (ctrl_data),
    .wr_ctrl      (wr_ctrl),
    .status       (status)
  );

  // request reading of first 7 RTC regs 0-6
  // 06 05 04 03 02 01 00
  // YY:MM:DD WD HH:MM:SS
  reg [7:0] datetime[0:6];
  reg [2:0] reg_addr, prev_reg_addr;
  reg [c_slow_bits:0] slow; // counter to slow down

  // request-to-read pulse
  always @(posedge clk)
  begin
    if (slow[c_slow_bits]) begin
      slow <= 0;
    end else begin
      slow <= slow+1;
    end
  end
  assign wr_ctrl = slow[c_slow_bits];
  
  // cycle to registers
  always @(posedge clk)
  begin
    if (slow[c_slow_bits]) begin
      if (reg_addr == 0)
        reg_addr <= 6;
      else
        reg_addr <= reg_addr-1;
      prev_reg_addr <= reg_addr;
    end
  end
  
  // take data when ready to register
  reg prev_busy;
  wire busy = status[31];
  wire ready = status[28];
  always @(posedge clk)
  begin
    if (ready & prev_busy & ~busy) begin
      datetime[prev_reg_addr] <= status[7:0];
      if (prev_reg_addr == 0)
        tick <= 1; 
    end else
      tick <= 0;
    prev_busy <= busy;
  end

  // Write 'h44 to register 'h55 in I2C slave 'h66
  //assign ctrl_data = 32'h00665544;

  // Write 'h20 to register 'h06 in I2C slave 'h6F
  //assign ctrl_data = 32'h006F0620;

  // Read from register 'h00 (seconds) in I2C slave 'h6F (RTC MCP7940N)
  //assign ctrl_data = 32'h006F0000;

  assign ctrl_data[31:16] = 16'h806F;
  assign ctrl_data[15:8] = reg_addr;
  assign ctrl_data[7:0] = 0;

  // missing bits should be 0
  assign datetime_o[ 7:0 ] = datetime[0][6:0]; // seconds
  assign datetime_o[15:8 ] = datetime[1][6:0]; // minutes
  assign datetime_o[23:16] = datetime[2][5:0]; // hours
  assign datetime_o[31:24] = datetime[3][2:0]; // weekday
  assign datetime_o[39:32] = datetime[4][6:0]; // day
  assign datetime_o[47:40] = datetime[5][4:0]; // month
  assign datetime_o[55:48] = datetime[6][7:0]; // year

endmodule

`default_nettype wire
