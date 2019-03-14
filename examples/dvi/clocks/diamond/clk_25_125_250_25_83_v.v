module clk_25_125_250_25_83
(
  input clkin_25MHz,
  output clk_125MHz,
  output clk_250MHz,
  output clk_25MHz,
  output clk_83M333Hz,
  output locked
);

  clk_25_125_250_25_83_vhd
  clk_25_125_250_25_83_instance
  (
    .CLKI(clkin_25MHz),
    .CLKOP(clk_125MHz),
    .CLKOS(clk_250MHz),
    .CLKOS2(clk_25MHz),
    .CLKOS3(clk_83MHz),
    .LOCKED(locked)
  );

endmodule
