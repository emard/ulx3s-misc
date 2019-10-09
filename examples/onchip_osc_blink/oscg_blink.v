// AUTHOR=EMARD
// LICENSE=BSD

// blink LED example using on-chip oscillator

module oscg_blink
(
  output [7:0] led
);
  parameter oscillator_divider = 12; // f=310MHz/divider = 310/12 = 25.8 MHz
  parameter counter_bits = 28;

  wire clk;

  // on-chip oscillator
  OSCG
  #(
    .DIV(oscillator_divider) // freq = 310MHz/div, div = 2..128
  )
  oscg_instance
  (
    .OSC(clk)
  );

  reg [counter_bits-1:0] counter;
  always @(posedge clk)
    counter <= counter + 1;
  
  assign led = counter[counter_bits-1:counter_bits-8];

endmodule
