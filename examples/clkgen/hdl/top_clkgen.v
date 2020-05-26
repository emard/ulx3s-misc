module top_clkgen
(
  input clk_25mhz,
  input [6:0] btn,
  output [7:0] led,
  output wifi_gpio0
);
  assign wifi_gpio0 = btn[0];
  
  wire [3:0] clocks;
  clkgen
  #(
    .in_hz   ( 25000000),
    .out0_hz (250000000)
  )
  clkgen_inst
  (
    .clk_i   ( clk_25mhz),
    .clk_o   ( clocks )
  );

  assign led = btn;
endmodule
