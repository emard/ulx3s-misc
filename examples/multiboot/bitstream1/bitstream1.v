// AUTHOR=EMARD
// LICENSE=BSD

// turn on LED
// exit bitstream on BTN0 with timed fuze

module bitstream1
(
  input  clk_25mhz,
  input  [6:0] btn,
  output [7:0] led,
  output user_programn
);
  assign led = 8'b00000010;
  // press BTN0 to exit this bitstream
  reg [19:0] R_delay_reload = 0;
  always @(posedge clk_25mhz)
    if(R_delay_reload[19]==0)
      R_delay_reload <= R_delay_reload+1;
  assign user_programn = btn[0] | ~R_delay_reload[19];
endmodule
