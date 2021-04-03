`default_nettype none
module top_fm
#(
  parameter abcxyz =  0
)
(
  input        clk_25mhz,
  input  [6:0] btn,
  output [7:0] led,
  output       ant_433mhz,
  output       wifi_gpio0
);
  // clock generator
  wire clk_locked;
  wire [3:0] clocks;
  wire clk = clocks[0];
  wire clk_fmdds = clocks[1];
  ecp5pll
  #(
      .in_hz( 25*1000000),
    .out0_hz( 25*1000000),
    .out1_hz(250*1000000)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks),
    .locked(clk_locked)
  );

  reg [15:0] beep;
  always @(posedge clk)
    beep <= beep+1;

  reg [7:0] rds_ram[0:51];
  initial
    $readmemh("message_ps.mem", rds_ram);
  wire [5:0] rds_addr;
  reg  [7:0] rds_data;
  always @(posedge clk)
    rds_data <= rds_ram[rds_addr];
  fmgen_test
  //#(
  //  .C_fmdds_hz(250*1000000),
  //  .C_rds_clock_multiply(228),
  //  .C_rds_clock_divide(3125)
  //)
  fmgen_test_inst
  (
    .clk(clk),
    .clk_fmdds(clk_fmdds),
    .pcm_in_left(btn[1] ? beep[15:1] : 0), // beep, may spoil RDS
    .pcm_in_right(btn[2] ? beep[15:1] : 0), // beep, may spoil RDS
    .cw_freq(107900000),
    .rds_addr(rds_addr),
    .rds_data(rds_data),
    .fm_antenna(ant_433mhz)
  );

  assign led = rds_data;

endmodule
`default_nettype wire
