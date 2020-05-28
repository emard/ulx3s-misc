module top_ecp5pll
#(
  parameter    bits = 26
)
(
  input        clk_25mhz,
  input  [6:0] btn,
  output [7:0] led,
  output       wifi_gpio0
);
  assign wifi_gpio0 = btn[0];
  
  wire [3:0] clocks;
  ecp5pll
  #(
      .in_hz(25000000),
    .out0_hz(40000000),
    .out1_hz(50000000), .out1_deg( 90),
    .out2_hz(60000000), .out2_deg(180),
    .out3_hz( 6000000), .out3_deg(300)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks)
  );

  generate
    genvar i;
    for(i = 0; i < 4; i=i+1)
    begin
      reg [bits-1:0] R_blink;
      always @(posedge clocks[i])
        R_blink <= R_blink+1;
      assign led[i*2+1:i*2] = R_blink[bits-1:bits-2];
    end
  endgenerate

endmodule
