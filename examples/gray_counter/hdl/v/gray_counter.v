module gray_counter
#(
  parameter bits = 8
)
(
  input  wire            clk,
  input  wire            reset,
  input  wire            enable,
  output wire [bits-1:0] gray_count
);

// Implementation:
// There is an imaginary bit in the counter, at q(0), that resets to 1
// (unlike the rest of the bits of the counter) and flips every clock cycle.
// The decision of whether to flip any non-imaginary bit in the counter
// depends solely on the bits below it, down to the imaginary bit.	It flips
// only if all these bits, taken together, match the pattern 10* (a one
// followed by any number of zeros).
// Almost every non-imaginary bit has a component instance that sets the 
// bit based on the values of the lower-order bits, as described above.
// The rules have to differ slightly for the most significant bit or else 
// the counter would saturate at it's highest value, 1000...0.
// (values are shifted to make room for the imaginary bit at q(0))
  reg  [bits:0] q;  // no_ones_below(x) = 1 iff there are no 1's in q below q(x)
  wire [bits:0] q_next;
  wire [bits:0] no_ones_below;  // q_msb is a modification to make the msb logic work
  wire          q_msb;

  // There are never any 1's beneath the lowest bit
  assign no_ones_below[0] = 1'b1;
  generate
    genvar i;
    for (i=1; i <= bits; i = i + 1)
    begin
      // Flip q(i) if lower bits are a 1 followed by all 0's
      assign q_next[i] = q[i] ^ (q[i - 1] & no_ones_below[i - 1]);
      assign no_ones_below[i] = no_ones_below[i-1] & ~q[i-1];
    end
  endgenerate

  assign q_msb = q[bits] | q[bits - 1];
  always @(posedge clk) begin
    if((reset == 1'b1)) begin
      // Resetting involves setting the imaginary bit to 1
      q[0] <= 1'b1;
      q[bits:1] <= {bits{1'b0}};
    end
    else if(enable == 1'b1) begin
      // Toggle the imaginary bit
      q[0] <= ~q[0];
      q[bits-1:1] <= q_next[bits-1:1];
      // i
      q[bits] <= q[bits] ^ (q_msb & no_ones_below[bits - 1]);
    end
  end

  assign gray_count = q[bits:1];

endmodule
